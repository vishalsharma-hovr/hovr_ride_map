package com.hovr.hovr_ride_map.route

import android.content.Context
import android.graphics.Color
import android.location.Location
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.TextView
import com.hovr.hovr_ride_map.model.ComputeRoutesResponse
import com.hovr.hovr_ride_map.model.StopLocation
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions
import com.google.android.gms.maps.model.Polyline
import com.google.android.gms.maps.model.PolylineOptions
import com.google.gson.Gson
import com.google.maps.android.PolyUtil
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.hovr.hovr_ride_map.R
import com.hovr.hovr_ride_map.RideViewChannelHub
import com.hovr.hovr_ride_map.ride.RideMapRouteClearState
import com.hovr.hovr_ride_map.shared.MapChromePolicy
import com.hovr.hovr_ride_map.utils.MapViewUtils
import com.hovr.hovr_ride_map.utils.MapViewUtils.createBitmapFromView
import com.hovr.hovr_ride_map.utils.MapViewUtils.formatDurationHMS
import com.hovr.hovr_ride_map.utils.MapViewUtils.getPlaceNameFromCoordinates
import kotlin.math.*

internal class RoutePreviewPlatformView(
    context: Context, messenger: BinaryMessenger, argsMap: Map<*, *>, originVal: LatLng
) : PlatformView, OnMapReadyCallback {

    // ✅ Fixed context — ignores system font scale
    private val fixedContext: Context = MapViewUtils.createFixedFontScaleContext(context)
    private val mapView: MapView = MapView(context)
    private lateinit var mMap: GoogleMap

    // Map Fragment
    private var durationText: String = ""
    private var origin: LatLng
    private var destination: LatLng

    var computeRoutesResponse: ComputeRoutesResponse
    private var stopsList: List<StopLocation> = emptyList()
    private var dropoffLocationName: String = ""

    private val startingPointView = LayoutInflater.from(fixedContext).inflate(R.layout.eta_marker, null)
    private val etaTextView = startingPointView.findViewById<TextView>(R.id.eta_text)

    // Re-center the route map via a dedicated channel (avoids ride-view-channel conflicts).
    private val reCenterMethodChannel: MethodChannel = MethodChannel(messenger, "routes-on-map-view")
    private var routeBounds: LatLngBounds? = null
    private var routePadding: Int = 120
    private val activePolylines = mutableListOf<Polyline>()
    private val activeMarkers = mutableListOf<Marker>()
    private var startMarker: Marker? = null
    private var pendingDriverEtaSeconds: Int? = null
    private var rideViewHandlerRegistered = false
    private var routeDrawGeneration = 0
    private var routeExplicitlyCleared = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private fun onMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    private val rideViewHandler = MethodChannel.MethodCallHandler { call, result ->
        when (call.method) {
            "eta-channel" -> {
                val args = call.arguments as? Map<*, *>
                val seconds = when (val raw = args?.get("eta")) {
                    is Int -> raw
                    is Number -> raw.toInt()
                    else -> null
                }
                if (seconds != null) {
                    applyDriverEtaSeconds(seconds)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    init {
        mapView.onCreate(null)
        mapView.getMapAsync(this)
        registerRecenterHandler()
        registerRideViewHandler()

        MethodChannel(messenger, "ETA_MARKER").setMethodCallHandler { call, result ->
            if (call.method == "eta") {
                val eta = call.arguments as? String
                val seconds = eta?.toIntOrNull()
                if (seconds != null) {
                    applyDriverEtaSeconds(seconds)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        val rawOrigin = LatLng(argsMap["pickup-lat"] as Double, argsMap["pickup-long"] as Double)
        val rawDestination = LatLng(argsMap["latitude"] as Double, argsMap["longitude"] as Double)
        val computeRoutesResponseJson = argsMap["computeRoutesResponseJson"]

        computeRoutesResponse = Gson().fromJson(computeRoutesResponseJson.toString(), ComputeRoutesResponse::class.java)

//        println(">>>>>> ROUTES : ${computeRoutesResponse.routes}")
        println(">>>>>> ROUTES Compute: $computeRoutesResponse")
        println(">>>>>> ROUTES Compute: ${argsMap["computeRoutesResponseJson"]}")

        stopsList = RouteStopParser.parse(argsMap["stops"])
        dropoffLocationName = argsMap["dropoff-location-name"] as? String ?: ""
        Log.d("RoutesOnMapView", "Parsed ${stopsList.size} stops from ${argsMap["stops"]}")
        val referencePoint = LatLng(43.73835115891842, -79.46301967454586)

        val originDistance = calculateDistanceInMeters(rawOrigin, referencePoint)
        val destinationDistance = calculateDistanceInMeters(rawDestination, referencePoint)

        origin = if (originDistance < 1200f) {
            Log.d("RouteInit", "Origin is near reference, snapping to fixed point.")
            referencePoint
        } else {
            rawOrigin
        }

        destination = if (destinationDistance < 1200f) {
            Log.d("RouteInit", "Destination is near reference, snapping to fixed point.")
            referencePoint
        } else {
            rawDestination
        }

        Log.d("DATAAAAA", "----->>>>>>>>>>>>>> argsMap $origin")
    }

    override fun getView(): View = mapView

    override fun dispose() {
        unregisterRideViewHandler()
        reCenterMethodChannel.setMethodCallHandler(null)
        mapView.onDestroy()
        onDestroy()
    }

    private fun registerRideViewHandler() {
        if (!rideViewHandlerRegistered) {
            RideViewChannelHub.push(rideViewHandler)
            rideViewHandlerRegistered = true
        }
    }

    private fun unregisterRideViewHandler() {
        if (rideViewHandlerRegistered) {
            RideViewChannelHub.pop(rideViewHandler)
            rideViewHandlerRegistered = false
        }
    }

    private fun etaMinutesLabel(seconds: Int): String {
        if (seconds <= 0) return "1"
        return max((seconds / 60.0).roundToInt(), 1).toString()
    }

    private fun applyDriverEtaSeconds(seconds: Int) {
        pendingDriverEtaSeconds = seconds
        etaTextView.text = etaMinutesLabel(seconds)
        refreshStartMarkerIcon()
    }

    private fun refreshStartMarkerIcon() {
        val marker = startMarker ?: return
        if (!::mMap.isInitialized) return
        val bitmap = BitmapDescriptorFactory.fromBitmap(createBitmapFromView(startingPointView))
        marker.setIcon(bitmap)
    }

    private fun registerRecenterHandler() {
        reCenterMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "recenter-map" -> {
                    performRouteRecenter()
                    result.success(null)
                }
                "clear-route" -> {
                    onMain { clearRouteStateAndOverlays() }
                    result.success(null)
                }
                "redraw-route-preview" -> {
                    val args = call.arguments as? Map<*, *>
                    val json = args?.get("computeRoutesResponseJson")?.toString()
                    if (json.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing computeRoutesResponseJson", null)
                        return@setMethodCallHandler
                    }
                    onMain {
                        computeRoutesResponse = Gson().fromJson(json, ComputeRoutesResponse::class.java)
                        routeExplicitlyCleared = false
                        if (::mMap.isInitialized) {
                            drawRoute(
                                computeRoutesResponse = computeRoutesResponse,
                                origin = origin,
                                destination = destination,
                            )
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun clearRouteStateAndOverlays() {
        routeDrawGeneration++
        routeExplicitlyCleared = true
        clearRouteOverlays()
    }

    private fun clearRouteOverlays() {
        activePolylines.forEach { it.remove() }
        activePolylines.clear()
        activeMarkers.forEach { it.remove() }
        activeMarkers.clear()
        startMarker = null
        routeBounds = null
    }

    private fun performRouteRecenter() {
        if (!::mMap.isInitialized) return
        val bounds = routeBounds ?: return
        val padding = routePadding
        val cameraUpdate = CameraUpdateFactory.newLatLngBounds(bounds, padding)
        mMap.animateCamera(cameraUpdate)
        Handler(Looper.getMainLooper()).postDelayed(
            {
                updateCameraPosition(mMap, origin, destination, padding, bounds)
                Handler(Looper.getMainLooper()).postDelayed(
                    { mMap.animateCamera(CameraUpdateFactory.zoomBy(-0.9f)) },
                    1200
                )
            },
            1200
        )
    }

    override fun onMapReady(map: GoogleMap) {
        mMap = map
        MapChromePolicy.apply(mMap)
        registerTaggedMarkerClickListener()
        // Initial draw from booking args; suppressed only after clear-route on this instance.
        if (!routeExplicitlyCleared) {
            drawRoute(
                origin = origin,
                destination = destination,
                computeRoutesResponse = computeRoutesResponse,
            )
        }
    }

    private fun registerTaggedMarkerClickListener() {
        mMap.setOnMarkerClickListener { marker ->
            val tag = marker.tag as? RouteTaggedMarkerTag ?: return@setOnMarkerClickListener false
            tag.expanded = !tag.expanded
            marker.setIcon(
                BitmapDescriptorFactory.fromBitmap(
                    RouteTaggedMarkerBitmap.bitmapFor(fixedContext, tag),
                ),
            )
            true
        }
    }

    private fun addTaggedMarker(position: LatLng, tag: RouteTaggedMarkerTag): Marker? {
        return mMap.addMarker(
            MarkerOptions()
                .position(position)
                .icon(
                    BitmapDescriptorFactory.fromBitmap(
                        RouteTaggedMarkerBitmap.bitmapFor(fixedContext, tag),
                    ),
                )
                .anchor(0.099f, 0.1f),
        )?.also { marker ->
            marker.tag = tag
            activeMarkers.add(marker)
        }
    }

    private fun onDestroy() {
        mapView.onDestroy()
    }

    private fun getDynamicPadding(distanceMeters: Float): Int {
        return when {
            distanceMeters < 2000 -> 150
            distanceMeters < 5000 -> 120
            distanceMeters < 10000 -> 100
            distanceMeters < 20000 -> 80
            distanceMeters < 50000 -> 60
            else -> 40
        }
    }

    private fun calculateDistanceInMeters(start: LatLng, end: LatLng): Float {
        val result = FloatArray(1)
        Location.distanceBetween(
            start.latitude, start.longitude, end.latitude, end.longitude, result
        )
        return result[0]
    }

    fun calculateBearing(from: LatLng, to: LatLng): Float {
        val lat1 = Math.toRadians(from.latitude)
        val lon1 = Math.toRadians(from.longitude)
        val lat2 = Math.toRadians(to.latitude)
        val lon2 = Math.toRadians(to.longitude)

        val deltaLon = lon2 - lon1
        val y = sin(deltaLon) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        val initialBearing = atan2(y, x)

        // Convert radians to degrees and normalize
        val bearing = (Math.toDegrees(initialBearing) + 360) % 360
        return bearing.toFloat()
    }

    fun updateCameraPosition(
        map: GoogleMap, origin: LatLng, destination: LatLng, padding: Int, bounds: LatLngBounds
    ) {
        val bearing = calculateBearing(origin, destination)

        Handler(Looper.getMainLooper()).postDelayed(
            {
                map.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, padding))

                // After the fit animation, update to add tilt and bearing
                Handler(Looper.getMainLooper()).postDelayed(
                    {
                        val center = LatLng(
                            (origin.latitude + destination.latitude) / 2, (origin.longitude + destination.longitude) / 2
                        )

                        val cameraPosition =
                            CameraPosition.Builder().target(center).zoom(map.cameraPosition.zoom).bearing(bearing)
                                .tilt(45f).build()

                        map.animateCamera(
                            CameraUpdateFactory.newCameraPosition(
                                cameraPosition
                            )
                        )
                    }, 300
                )
            }, 200
        )
    }

    private fun drawRoute(
        computeRoutesResponse: ComputeRoutesResponse,
        origin: LatLng,
        destination: LatLng,
    ) {
        routeExplicitlyCleared = false
        val generationAtStart = routeDrawGeneration
        CoroutineScope(Dispatchers.IO).launch {
            try {
                if (RideMapRouteClearState.isStaleDraw(generationAtStart, routeDrawGeneration)) {
                    Log.d("drawRoute", "Skipping stale route preview draw after clear")
                    return@launch
                }

                val route = computeRoutesResponse
                val encodedPolyline = route.polyline

                if (encodedPolyline.isNullOrBlank()) {
                    Log.w("drawRoute", "No polyline in route response")
                    return@launch
                }

                val decodedPath = PolyUtil.decode(encodedPolyline)
                durationText = route.durationSeconds
                val destinationName = getPlaceNameFromCoordinates(
                    context = fixedContext,
                    latitude = destination.latitude,
                    longitude = destination.longitude,
                ).orEmpty()
                val destinationAddress = dropoffLocationName.ifBlank { destinationName }
                val destinationTagLabel = formatDurationHMS(durationText)
                val pointA = origin
                val pointB = destination
                val boundsBuilder = LatLngBounds.Builder().apply {
                    include(pointA)
                    include(pointB)
                    decodedPath.forEach { include(it) }
                    stopsList.forEach { include(LatLng(it.latitude, it.longitude)) }
                }

                withContext(Dispatchers.Main) {
                    if (RideMapRouteClearState.isStaleDraw(generationAtStart, routeDrawGeneration)) {
                        Log.d("drawRoute", "Skipping stale route preview draw on main")
                        return@withContext
                    }

                    clearRouteOverlays()

                    // Uber-like casing + HOVR green stroke (same as in-trip ride map).
                    activePolylines.addAll(
                        com.hovr.hovr_ride_map.ride.RideMapRouteStyle.addCasingAndStroke(
                            mMap,
                            decodedPath,
                        ),
                    )

                    pendingDriverEtaSeconds?.let { etaTextView.text = etaMinutesLabel(it) }
                    val startBitmap = BitmapDescriptorFactory.fromBitmap(
                        createBitmapFromView(startingPointView)
                    )
                    startMarker = mMap.addMarker(
                        MarkerOptions().position(pointA).icon(startBitmap),
                    )
                    startMarker?.also { activeMarkers.add(it) }

                    addTaggedMarker(
                        position = decodedPath.last(),
                        tag = RouteTaggedMarkerTag(
                            kind = RouteTaggedMarkerKind.DESTINATION,
                            tagLabel = destinationTagLabel,
                            address = destinationAddress,
                        ),
                    )
                    val routeDistance = calculateDistanceInMeters(pointA, pointB)
                    // Camera logic
                    val padding = getDynamicPadding(routeDistance) - 20

                    try {
                        val bounds = boundsBuilder.build()
                        routeBounds = bounds
                        routePadding = padding
                        val cameraUpdate = CameraUpdateFactory.newLatLngBounds(bounds, padding)
                        mMap.animateCamera(cameraUpdate)
                        Handler(Looper.getMainLooper()).postDelayed(
                            {
                                updateCameraPosition(
                                    mMap, origin, destination, padding, bounds
                                )
                                Handler(Looper.getMainLooper()).postDelayed(
                                    {
                                        mMap.animateCamera(
                                            CameraUpdateFactory.zoomBy(
                                                -0.9f
                                            )
                                        )
                                    }, 1200
                                )
                            }, 1200
                        )

                        stopsList.forEachIndexed { index, stop ->
                            val position = LatLng(stop.latitude, stop.longitude)
                            val stopNumber = index + 1
                            val stopLabel = "Stop $stopNumber"
                            addTaggedMarker(
                                position = position,
                                tag = RouteTaggedMarkerTag(
                                    kind = RouteTaggedMarkerKind.STOP,
                                    tagLabel = stopLabel,
                                    address = stop.address.ifBlank { stopLabel },
                                    stopNumber = stopNumber,
                                ),
                            )

                            Log.d(
                                "RoutesOnMapView",
                                "Added stop marker: $stop at ${stop.latitude}, ${stop.longitude}",
                            )
                        }

                    } catch (e: Exception) {
                        e.printStackTrace()
                        mMap.animateCamera(
                            CameraUpdateFactory.newLatLngZoom(pointA, 12f)
                        )
                    }

                    Log.d("drawRoute", "Route duration: ${route.durationSeconds}")
                }
            } catch (e: Exception) {
                Log.e("drawRoute", "Exception: ${e.message}")
            }
        }
    }
}