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
import com.hovr.hovr_ride_map.utils.MapViewUtils.createBitmapFromView
import com.hovr.hovr_ride_map.utils.MapViewUtils.formatDurationHMS
import com.hovr.hovr_ride_map.utils.MapViewUtils.getPlaceNameFromCoordinates
import com.hovr.hovr_ride_map.utils.createFixedFontScaleContext
import kotlin.math.*

internal class RoutePreviewPlatformView(
    context: Context, messenger: BinaryMessenger, argsMap: Map<*, *>, originVal: LatLng
) : PlatformView, OnMapReadyCallback {

    // ✅ Fixed context — ignores system font scale
    private val fixedContext: Context = context.createFixedFontScaleContext()
    private val mapView: MapView = MapView(context)
    private lateinit var mMap: GoogleMap

    // Map Fragment
    private var durationText: String = ""
    private var origin: LatLng
    private var destination: LatLng

    var computeRoutesResponse: ComputeRoutesResponse
    private var stopsList: List<StopLocation> = emptyList()

    /*
     *  marker
     */
    private val markerView = LayoutInflater.from(fixedContext).inflate(R.layout.custom_marker, null)


    private val timeTextView = markerView.findViewById<TextView>(R.id.timeTextView)
    private val addressTextView = markerView.findViewById<TextView>(R.id.addressTextView)

    //    private val startingPointView = LayoutInflater.from(context).inflate(R.layout.custom_starting_point, null)
    private val startingPointView = LayoutInflater.from(fixedContext).inflate(R.layout.eta_marker, null)
    private val etaTextView = startingPointView.findViewById<TextView>(R.id.eta_text)

    // Re-center the route map via a dedicated channel (avoids ride-view-channel conflicts).
    private val reCenterMethodChannel: MethodChannel = MethodChannel(messenger, "routes-on-map-view")
    private var routeBounds: LatLngBounds? = null
    private var routePadding: Int = 120
    private val activePolylines = mutableListOf<Polyline>()
    private val activeMarkers = mutableListOf<Marker>()

    init {
        mapView.onCreate(null)
        mapView.getMapAsync(this)
        registerRecenterHandler()

        MethodChannel(messenger, "ETA_MARKER").setMethodCallHandler { call, result ->
            if (call.method == "eta") {
                val eta = call.arguments as String
                println(">>>>>>> ETA >>>>> $eta")
                etaTextView.text = eta
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

        //MARK: STOPS
        val stopsData = argsMap["stops"] as? List<Map<String, Any>>
        Log.d("RoutesOnMapView", "STOPS : : : $stopsData stops")
        if (stopsData != null) {
            stopsList = stopsData.mapNotNull { stopMap ->
                try {
                    val latitude = stopMap["latitude"] as? Double ?: return@mapNotNull null
                    val longitude = stopMap["longitude"] as? Double ?: return@mapNotNull null
                    val address = stopMap["address"] as? String ?: ""
                    StopLocation(latitude, longitude, address)
                } catch (e: Exception) {
                    Log.e("RoutesOnMapView", "Error parsing stop: ${e.message}")
                    null
                }
            }
            Log.d("RoutesOnMapView", "Parsed ${stopsList.size} stops")
        }
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

        addressTextView.setOnClickListener { Log.d("PlatformView", "TextView clicked") }

        Log.d("DATAAAAA", "----->>>>>>>>>>>>>> argsMap $origin")
    }

    override fun getView(): View = mapView

    override fun dispose() {
        reCenterMethodChannel.setMethodCallHandler(null)
        mapView.onDestroy()
        onDestroy()
    }

    private fun registerRecenterHandler() {
        reCenterMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "recenter-map" -> {
                    performRouteRecenter()
                    result.success(null)
                }
                "clear-route" -> {
                    clearRouteOverlays()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun clearRouteOverlays() {
        activePolylines.forEach { it.remove() }
        activePolylines.clear()
        activeMarkers.forEach { it.remove() }
        activeMarkers.clear()
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
        mMap.uiSettings.isCompassEnabled = false
        drawRoute(
            origin = origin, destination = destination, computeRoutesResponse = computeRoutesResponse
        )
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
        CoroutineScope(Dispatchers.IO).launch {
            try {
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
                    longitude = destination.longitude
                )

                addressTextView.text = destinationName

                timeTextView.text = formatDurationHMS(durationText)
                val pointA = origin
                val pointB = destination
                val boundsBuilder = LatLngBounds.Builder().apply {
                    include(pointA)
                    include(pointB)
                    decodedPath.forEach { include(it) }
                }

                withContext(Dispatchers.Main) {
                    clearRouteOverlays()

                    mMap.addPolyline(
                        PolylineOptions().addAll(decodedPath).color(Color.rgb(74, 171, 36)).width(10f)
                    ).also { activePolylines.add(it) }

                    // Optional: Add markers
                    val startBitmap = BitmapDescriptorFactory.fromBitmap(
                        createBitmapFromView(startingPointView)
                    )
                    val endBitmap = BitmapDescriptorFactory.fromBitmap(
                        createBitmapFromView(markerView)
                    )
                    mMap.addMarker(MarkerOptions().position(pointA).icon(startBitmap))
                        ?.also { activeMarkers.add(it) }
                    mMap.addMarker(
                        MarkerOptions().position(decodedPath.last()).icon(endBitmap)
                            .anchor(0.099f, .1f)
                    )?.also { activeMarkers.add(it) }
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

                        //MARK: Stop Location MARKER
                        stopsList.forEachIndexed { index, stop ->
                            val position = LatLng(stop.latitude, stop.longitude)

                            mMap.addMarker(
                                MarkerOptions().position(position).icon(startBitmap).title(stop.address)
                            )?.also { activeMarkers.add(it) }

                            Log.d(
                                "RoutesOnMapView", "Added stop marker: $stop at ${stop.latitude}, ${stop.longitude}"
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