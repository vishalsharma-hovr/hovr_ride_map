package com.hovr.hovr_ride_map.ride

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.location.Location
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.createBitmap
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.hovr.hovr_ride_map.shared.BearingSmoother
import com.hovr.hovr_ride_map.RideViewChannelHub
import com.google.android.gms.location.*
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.model.*
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.maps.android.SphericalUtil
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.*
import com.hovr.hovr_ride_map.R
import com.hovr.hovr_ride_map.shared.calculateBearing

internal class RideMapPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    private val mapMode: String? = null,
    private val savedInstanceState: Bundle? = null,
) : PlatformView, OnMapReadyCallback, DefaultLifecycleObserver {

    private var currentTripStage: String? = mapMode
    private var lastAppliedTripStage: String? = null

    private val mapView = MapView(context)
    private var googleMap: GoogleMap? = null
    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context.applicationContext)
    private val mainLooper: Looper = Looper.getMainLooper()

    private var userMarker: Marker? = null
    private var hasMovedCamera = false
    private var currentIconSizeDp = -1
    private var destIconCached: BitmapDescriptor? = null
    private var carIconCached: BitmapDescriptor? = null

    private val carIconCache = mutableMapOf<Int, BitmapDescriptor>()
    private val userIconCache = mutableMapOf<Int, BitmapDescriptor>()

    private val activePolylines = mutableListOf<Polyline>()

    private var startMarker: Marker? = null
    private var destMarker: Marker? = null
    private var carMarker: Marker? = null
    private var polylinePoints: List<LatLng> = emptyList()
    private var currentPolylineIndex = 0
    private val activeMarkers = mutableListOf<Marker>()

    private val TAG = "drawRoute"
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingRoute: Pair<String, String?>? = null
    private var pendingPolylineString: String? = null
    private var savedPolylineString: String? = null
    private var lastDrawnPolyline: String? = null

    private var mapViewReady = false
    private var pendingRecenterFit: String? = null
    private var shouldRestoreRoute = false
    private var hasRestoredRoute = false
    private var isAppInForeground = false
    private var currentTripId: String? = null

    private var segmentBearings: FloatArray = floatArrayOf()
    private val bearingSmoother = BearingSmoother(alpha = 0.35f)
    private var followOffsetMeters = 60.0
    private var followTilt = 45f
    private var followZoom = 17f
    private var lastDriverLatLng: LatLng? = null
    private var lastDropoffLatLng: LatLng? = null
    private var lastPickupLatLng: LatLng? = null
    private var lastUserLatLng: LatLng? = null

    private val sharedPrefs by lazy {
        context.getSharedPreferences("MeetAtPickupSpotView", Context.MODE_PRIVATE)
    }

    private fun onMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    private val rideViewHandler = MethodChannel.MethodCallHandler { call, result ->
        when (call.method) {
            "recenter-map" -> {
                val arg = call.arguments as? Map<*, *>
                val fit = arg?.get("fit") as? String
                recenterMap(result, fit)
            }

            "polylines-channel" -> {
                Log.d(TAG, "=== POLYLINES-CHANNEL CALLED ===")
                val arg = call.arguments as? Map<*, *>
                if (arg == null) {
                    result.error("INVALID_ARGS", "Expected Map arguments", null)
                    return@MethodCallHandler
                }

                val args = arg["polyline"] as? String
                if (args.isNullOrEmpty()) {
                    result.error("INVALID_POLYLINE", "Polyline cannot be empty", null)
                    return@MethodCallHandler
                }

                onMain {
                    setRoute(args, "")
                }
                result.success(null)
            }

            "driver-location-update" -> {
                val arg = call.arguments as? Map<*, *>
                val driverLat = arg?.get("lat") as? Double
                val driverLng = arg?.get("lng") as? Double

                if (driverLat != null && driverLng != null) {
                    onMain {
                        val position = LatLng(driverLat, driverLng)
                        lastDriverLatLng = position
                        val marker = carMarker ?: startMarker
                        marker?.position = position
                    }
                    result.success("Location received successfully!")
                } else {
                    result.error("INVALID_LOCATION", "Driver location missing", null)
                }
            }

            "drop-off-location" -> {
                val arg = call.arguments as? Map<*, *>
                val lat = arg?.get("lat") as? Double
                val lng = arg?.get("lng") as? Double
                if (lat != null && lng != null) {
                    lastDropoffLatLng = LatLng(lat, lng)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing dropoff lat/lng", null)
                }
            }

            "pickup-location" -> {
                val arg = call.arguments as? Map<*, *>
                val lat = arg?.get("lat") as? Double
                val lng = arg?.get("lng") as? Double
                if (lat != null && lng != null) {
                    lastPickupLatLng = LatLng(lat, lng)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing pickup lat/lng", null)
                }
            }

            "user-location" -> {
                val arg = call.arguments as? Map<*, *>
                val lat = arg?.get("lat") as? Double
                val lng = arg?.get("lng") as? Double
                if (lat != null && lng != null) {
                    lastUserLatLng = LatLng(lat, lng)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing user lat/lng", null)
                }
            }

            "clear-route" -> {
                clearSavedRoute()
                savedPolylineString = null
                lastDrawnPolyline = null
                pendingPolylineString = null
                pendingRoute = null
                shouldRestoreRoute = false
                hasRestoredRoute = false
                polylinePoints = emptyList()
                currentPolylineIndex = 0

                clearMapElements()
                result.success(null)
            }

            "trip-stage" -> {
                val arg = call.arguments as? Map<*, *>
                val stage = arg?.get("tripStage") as? String
                if (stage.isNullOrEmpty()) {
                    result.error("INVALID_ARGS", "Missing tripStage", null)
                    return@MethodCallHandler
                }
                if (stage == currentTripStage) {
                    result.success(null)
                    return@MethodCallHandler
                }
                currentTripStage = stage
                applyTripStage(stage)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    fun setRoute(polyline: String, eta: String?) {
        CoroutineScope(Dispatchers.Main).launch {
            savedPolylineString = polyline
            lastDrawnPolyline = polyline
            saveRouteToPrefs(polyline)
            pendingRoute = null
            pendingPolylineString = null

            when {
                googleMap == null -> {
                    pendingRoute = polyline to eta
                    pendingPolylineString = polyline
                    Log.d(TAG, "Map not ready yet; queued route len=${polyline.length}")
                }

                !mapViewReady -> {
                    pendingPolylineString = polyline
                    Log.d(TAG, "MapView not yet laid out; deferring route draw")
                }

                else -> {
                    Log.d(TAG, "Drawing route directly — map & layout ready")
                    drawRoute(polyline)
                }
            }
        }
    }

    private fun saveRouteToPrefs(polyline: String, tripId: String? = null) {
        try {
            if (tripId != null) {
                currentTripId = tripId
                sharedPrefs.edit().putString("current_trip_id", tripId).apply()
            }

            sharedPrefs.edit().putString("last_polyline", polyline).apply()
            Log.d(TAG, "✅ Route saved for trip: $tripId (len=${polyline.length})")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save route: ${e.message}")
        }
    }

    private fun loadRouteFromPrefs(requestedTripId: String? = null): String? {
        return try {
            val savedTripId = sharedPrefs.getString("current_trip_id", null)
            val route = sharedPrefs.getString("last_polyline", null)

            // Only load if trip IDs match (or no trip ID check needed)
            if (requestedTripId != null && savedTripId != requestedTripId) {
                Log.d(TAG, "Trip ID mismatch: saved=$savedTripId, requested=$requestedTripId")
                return null
            }

            if (route != null) {
                Log.d(TAG, "✅ Loaded route for trip: $savedTripId (len=${route.length})")
            }
            route
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load route: ${e.message}")
            null
        }
    }

    private fun clearSavedRoute() {
        sharedPrefs.edit().remove("last_polyline").apply()
        sharedPrefs.edit().remove("current_trip_id").apply()
        currentTripId = null
        Log.d(TAG, "✅ Cleared saved route from SharedPreferences")
    }


    init {
        mapView.onCreate(savedInstanceState)
        mapView.getMapAsync(this)

        // ✅ Load saved route ONCE at the very start
        val savedRoute = loadRouteFromPrefs()
        if (savedRoute != null && savedRoute.isNotEmpty()) {
            savedPolylineString = savedRoute
            lastDrawnPolyline = savedRoute
            Log.d(TAG, "🎯 Init: Route loaded from prefs")
        } else {
            Log.d(TAG, "Init: No saved route")
        }

        // Window focus detection
        mapView.viewTreeObserver.addOnWindowFocusChangeListener { hasFocus ->
            Log.d(TAG, "🔍 Window focus: $hasFocus, prevState=$isAppInForeground")

            if (hasFocus) {
                if (!isAppInForeground) {
                    isAppInForeground = true
                    Log.d(TAG, "🟢 App RESUMED")
                    handleAppResume()
                }
            } else {
                if (isAppInForeground) {
                    isAppInForeground = false
                    Log.d(TAG, "🔴 App PAUSED")
                    handleAppPause()
                }
            }
        }

        // View attach/detach
        mapView.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                Log.d(TAG, "🟢 View ATTACHED")
                isAppInForeground = true
                try {
                    mapView.onStart()
                    mapView.onResume()
                } catch (e: Exception) {
                    Log.e(TAG, "Error in onViewAttachedToWindow: ${e.message}")
                }
            }

            override fun onViewDetachedFromWindow(v: View) {
                Log.d(TAG, "🔴 View DETACHED")
                isAppInForeground = false
                try {
                    mapView.onPause()
                    mapView.onStop()
                } catch (e: Exception) {
                    Log.e(TAG, "Error in onViewDetachedFromWindow: ${e.message}")
                }
            }
        })

        RideViewChannelHub.push(rideViewHandler)

        // Layout listener
        mapView.viewTreeObserver.addOnGlobalLayoutListener {
            if (!mapViewReady && mapView.width > 0 && mapView.height > 0) {
                mapViewReady = true
                Log.d(TAG, "🟢 MapView layout complete")

                // ✅ Check ALL sources
                val savedRoute = loadRouteFromPrefs()
                val routeToDraw = pendingPolylineString ?: savedPolylineString ?: savedRoute

                if (routeToDraw != null && routeToDraw.isNotEmpty()) {
                    Log.d(TAG, "📍 Drawing route after layout (len=${routeToDraw.length})")
                    pendingPolylineString = null
                    savedPolylineString = routeToDraw
                    lastDrawnPolyline = routeToDraw

                    CoroutineScope(Dispatchers.Main).launch {
                        drawRoute(routeToDraw)
                    }
                } else {
                    Log.d(TAG, "No route to draw after layout")
                }

                flushPendingRecenter()
            }
        }
    }

    private fun handleAppPause() {
        Log.d(TAG, "🔴 handleAppPause")

        if (lastDrawnPolyline != null && lastDrawnPolyline!!.isNotEmpty()) {
            saveRouteToPrefs(lastDrawnPolyline!!)
            shouldRestoreRoute = true
            Log.d(TAG, "Marked for restoration")
        }
    }

    private fun handleAppResume() {
        Log.d(TAG, "🟢 handleAppResume")

        Handler(Looper.getMainLooper()).postDelayed({
            if (googleMap != null && mapViewReady) {
                val savedRoute = loadRouteFromPrefs()
                val route = lastDrawnPolyline ?: savedPolylineString ?: savedRoute

                if (route != null && route.isNotEmpty()) {
                    val hasRoute = activePolylines.isNotEmpty() &&
                            startMarker != null &&
                            destMarker != null

                    if (!hasRoute) {
                        Log.d(TAG, "✅ Restoring route (len=${route.length})")
                        hasRestoredRoute = true
                        shouldRestoreRoute = false

                        clearMapElements()
                        drawRoute(route)
                    } else {
                        Log.d(TAG, "Route already drawn")
                    }
                } else {
                    Log.d(TAG, "No route to restore")
                }
            } else {
                Log.d(TAG, "Map not ready (map=${googleMap != null}, ready=$mapViewReady)")
            }
        }, 600)
    }

    private fun clearMapElements() {
        Log.d(TAG, "🧹 Clearing map elements")

        onMain {
            try {
                activePolylines.forEach {
                    try {
                        it.remove()
                    } catch (e: Exception) {
                    }
                }
                activePolylines.clear()

                activeMarkers.forEach {
                    try {
                        it.remove()
                    } catch (e: Exception) {
                    }
                }
                activeMarkers.clear()

                startMarker?.remove()
                startMarker = null

                destMarker?.remove()
                destMarker = null

                carMarker?.remove()
                carMarker = null

                userMarker?.remove()
                userMarker = null

                Log.d(TAG, "✅ Cleared")
            } catch (e: Exception) {
                Log.e(TAG, "Error clearing: ${e.message}")
            }
        }
    }

    private fun markerIconFromDrawable(ctx: Context, resId: Int, sizeDp: Int): BitmapDescriptor {
        val sizePx = (sizeDp * ctx.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        val src = BitmapFactory.decodeResource(ctx.resources, resId) ?: error("Drawable not found")
        val scaled = if (src.width == sizePx && src.height == sizePx) src
        else Bitmap.createScaledBitmap(src, sizePx, sizePx, true)
        return BitmapDescriptorFactory.fromBitmap(scaled)
    }

    private fun getCarIcon(ctx: Context, sizeDp: Int = 42): BitmapDescriptor {
        return carIconCached ?: markerIconFromDrawable(ctx, R.drawable.car, sizeDp).also {
            carIconCached = it
        }
    }

    private fun getDestinationIcon(ctx: Context, sizeDp: Int = 56): BitmapDescriptor {
        return destIconCached ?: getBitmapDescriptorFromVector(
            ctx,
            R.drawable.circle_with_broad_green_background,
            sizeDp,
            sizeDp
        ).also {
            destIconCached = it
        }
    }

    fun drawRoute(polyline: String) {
        Log.d(TAG, "📍 drawRoute() CALLED - len=${polyline.length}")

        val map = googleMap
        if (map == null) {
            Log.w(TAG, "Map NULL")
            return
        }

        if (!mapViewReady) {
            Log.w(TAG, "MapView not ready")
            pendingPolylineString = polyline
            return
        }

        val decodedPath = try {
            RideMapPolylineDecoder.safeDecodeAny(polyline)
        } catch (e: Exception) {
            Log.e(TAG, "Decode failed: ${e.message}")
            emptyList()
        }

        if (decodedPath.isEmpty()) {
            Log.w(TAG, "Decoded path empty")
            return
        }

        Log.d(TAG, "Decoded ${decodedPath.size} points")

        onMain launch@{
            lastDrawnPolyline = polyline
            savedPolylineString = polyline
            saveRouteToPrefs(polyline)
            hasRestoredRoute = true

            userMarker?.remove()
            userMarker = null

            polylinePoints = decodedPath
            currentPolylineIndex = 0

            bearingSmoother.reset()
            segmentBearings = if (decodedPath.size >= 2) {
                FloatArray(decodedPath.size) { i ->
                    if (i < decodedPath.size - 1)
                        calculateBearing(decodedPath[i], decodedPath[i + 1])
                    else
                        calculateBearing(decodedPath[i - 1], decodedPath[i])
                }
            } else {
                floatArrayOf(0f)
            }

            startMarker?.remove()
            startMarker = null

            activePolylines.forEach { it.remove() }
            activePolylines.clear()
            activeMarkers.forEach { it.remove() }
            activeMarkers.clear()

            val line = map.addPolyline(
                PolylineOptions()
                    .addAll(decodedPath)
                    .width(15f)
                    .color(Color.parseColor("#4AAB24"))
                    .geodesic(true)
                    .visible(true)
                    .zIndex(100f)
            )
            activePolylines += line

            val start = decodedPath.first()
            val initialBearing = segmentBearings[0]
            val initRot = bearingSmoother.apply(initialBearing)

            carMarker?.remove()

            startMarker = map.addMarker(
                MarkerOptions()
                    .position(start)
                    .title("Start")
                    .icon(getCarIcon(mapView.context, sizeDp = 42))
                    .anchor(0.5f, 0.5f)
                    .rotation(initRot)
                    .zIndex(200f)
                    .flat(true)
            )

            val end = decodedPath.last()
            destMarker?.remove()
            destMarker = map.addMarker(
                MarkerOptions()
                    .position(end)
                    .title("Destination")
                    .icon(getDestinationIcon(mapView.context, sizeDp = 26))
                    .visible(true)
                    .anchor(0.5f, 0.5f)
                    .zIndex(300f)
            )

            followStartMarker(initRot)
            hasMovedCamera = true

            Log.d(TAG, "✅ Route drawn")
        }
    }

    private fun followStartMarker(currentBearing: Float? = null) {
        val map = googleMap ?: return
        val m = startMarker ?: carMarker ?: return

        val bearing = currentBearing ?: m.rotation

        val target = if (followOffsetMeters > 0.0) {
            val headingDeg = ((bearing.toDouble() + 180.0) % 360.0)
            SphericalUtil.computeOffset(m.position, followOffsetMeters, headingDeg)
        } else {
            m.position
        }

        val cameraPos = CameraPosition.Builder()
            .target(target)
            .zoom(followZoom)
            .tilt(followTilt)
            .bearing(bearing)
            .build()

        map.moveCamera(CameraUpdateFactory.newCameraPosition(cameraPos))
    }

    override fun dispose() {
        RideViewChannelHub.pop(rideViewHandler)
        fusedLocationClient.removeLocationUpdates(locationCallback)
        mapView.onDestroy()
    }

    override fun onStart(owner: LifecycleOwner) = mapView.onStart()
    override fun onResume(owner: LifecycleOwner) = mapView.onResume()
    override fun onPause(owner: LifecycleOwner) = mapView.onPause()
    override fun onStop(owner: LifecycleOwner) = mapView.onStop()
    override fun onDestroy(owner: LifecycleOwner) = mapView.onDestroy()

    override fun getView(): View = mapView

    override fun onMapReady(map: GoogleMap) {
        Log.d(TAG, "=== onMapReady ===")

        googleMap = map.apply {
            isBuildingsEnabled = false
            mapType = GoogleMap.MAP_TYPE_NORMAL

            try {
                setMapStyle(MapStyleOptions.loadRawResourceStyle(mapView.context, R.raw.hovr_maps_style))
                Log.d(TAG, "✅ Map style applied")
            } catch (e: Exception) {
                Log.e(TAG, "Map style failed: ${e.message}")
            }
        }

        startLocationUpdates()

        // ✅ ALWAYS load from prefs
        val savedRoute = loadRouteFromPrefs()
        if (savedRoute != null && savedRoute.isNotEmpty()) {
            if (savedPolylineString == null || savedPolylineString!!.isEmpty()) {
                Log.d(TAG, "💾 Loading from SharedPreferences")
                savedPolylineString = savedRoute
                lastDrawnPolyline = savedRoute
            }
        }

        val routeToDraw = pendingRoute?.first ?: pendingPolylineString ?: savedPolylineString

        if (routeToDraw != null && routeToDraw.isNotEmpty()) {
            Log.d(TAG, "🗺️ Has route (len=${routeToDraw.length})")

            if (mapViewReady) {
                Log.d(TAG, "Drawing now")
                pendingRoute = null
                pendingPolylineString = null
                hasRestoredRoute = true
                drawRoute(routeToDraw)
            } else {
                Log.d(TAG, "Waiting for layout")
                pendingPolylineString = routeToDraw
            }
        } else {
            Log.d(TAG, "No route")
        }

        when (val stage = currentTripStage) {
            null -> if (routeToDraw.isNullOrEmpty()) moveToUserLocation()
            else -> applyTripStage(stage)
        }
    }

    private fun applyTripStage(stage: String) {
        if (stage == lastAppliedTripStage) return
        lastAppliedTripStage = stage
        onMain {
            when {
                RideMapStageApplier.prefersRouteCamera(stage) && polylinePoints.isNotEmpty() -> {
                    followStartMarker()
                }

                polylinePoints.isNotEmpty() && startMarker != null -> {
                    followStartMarker()
                }

                else -> {
                    moveToUserLocation(zoom = RideMapStageApplier.defaultZoom(stage))
                }
            }
            Log.d(TAG, "Applied trip stage: $stage")
        }
    }

    @SuppressLint("MissingPermission")
    private fun moveToUserLocation(zoom: Float = 15f) {
        if (!hasPermission()) return

        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                val pos = LatLng(location.latitude, location.longitude)
                googleMap?.animateCamera(CameraUpdateFactory.newLatLngZoom(pos, zoom))
                hasMovedCamera = true
                val icon = getUserIcon(currentIconSizeDp.takeIf { it > 0 }
                    ?: calculateSizeForZoom(googleMap?.cameraPosition?.zoom ?: 12f))
                if (userMarker == null) {
                    userMarker = googleMap?.addMarker(MarkerOptions().position(pos).anchor(0.5f, 0.5f).icon(icon))
                }
            }
        }
    }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let { updateUserLocation(it) }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startLocationUpdates() {
        if (!hasPermission()) return

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000L)
            .setMinUpdateIntervalMillis(10000L)
            .build()

        fusedLocationClient.requestLocationUpdates(request, locationCallback, mainLooper)
    }

    private fun hasPermission(): Boolean = ActivityCompat.checkSelfPermission(
        mapView.context, Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED

    private fun updateUserLocation(loc: Location) {
        // Minimal implementation
    }

    private fun buildRecenterState() = RideMapRecenter.State(
        lastDriverLatLng = lastDriverLatLng,
        carPosition = carMarker?.position,
        startPosition = startMarker?.position,
        destPosition = destMarker?.position,
        lastDropoffLatLng = lastDropoffLatLng,
        lastPickupLatLng = lastPickupLatLng,
        lastUserLatLng = lastUserLatLng,
        polylinePoints = polylinePoints,
        followZoom = followZoom,
    )

    private fun performRecenter(fit: String?): Boolean {
        val map = googleMap ?: return false
        if (!mapViewReady) return false

        val mapWidth = mapView.width
        val mapHeight = mapView.height
        val state = buildRecenterState()

        if (RideMapRecenter.applyFit(map, fit, state, mapWidth, mapHeight)) {
            return true
        }
        if (fit != null && RideMapRecenter.fitFullPolyline(map, state, mapWidth, mapHeight)) {
            return true
        }
        if (fit == null && RideMapRecenter.fitPolylineStart(map, state)) {
            return true
        }
        return false
    }

    private fun flushPendingRecenter() {
        val fit = pendingRecenterFit ?: return
        pendingRecenterFit = null
        if (!performRecenter(fit) && hasPermission()) {
            recenterToUserGpsFallback()
        }
    }

    @SuppressLint("MissingPermission")
    private fun recenterToUserGpsFallback() {
        if (!hasPermission()) return

        fusedLocationClient.lastLocation.addOnSuccessListener { cached ->
            if (cached != null) {
                val pos = LatLng(cached.latitude, cached.longitude)
                googleMap?.animateCamera(CameraUpdateFactory.newLatLngZoom(pos, 16f))
                return@addOnSuccessListener
            }

            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY,
                CancellationTokenSource().token,
            ).addOnSuccessListener { location ->
                location?.let {
                    val pos = LatLng(it.latitude, it.longitude)
                    googleMap?.animateCamera(CameraUpdateFactory.newLatLngZoom(pos, 16f))
                }
            }
        }
    }

    private fun recenterMap(result: MethodChannel.Result, fit: String? = null) {
        onMain {
            val map = googleMap
            if (map == null || !mapViewReady) {
                pendingRecenterFit = fit
                result.success(null)
                return@onMain
            }

            if (performRecenter(fit)) {
                pendingRecenterFit = null
                result.success(null)
                return@onMain
            }

            if (!hasPermission()) {
                result.error("NO_PERM", "Location permission not granted", null)
                return@onMain
            }

            recenterToUserGpsFallback()
            result.success(null)
        }
    }

    private fun calculateSizeForZoom(zoom: Float): Int = when {
        zoom >= 18f -> 50
        zoom >= 16f -> 45
        zoom >= 14f -> 40
        zoom >= 12f -> 30
        else -> 16
    }

    private fun getUserIcon(sizeDp: Int): BitmapDescriptor =
        userIconCache.getOrPut(sizeDp) {
            BitmapDescriptorFactory.fromBitmap(makeUserBitmap(sizeDp))
        }

    private fun getBitmapDescriptorFromVector(
        context: Context, vectorResId: Int, widthDp: Int, heightDp: Int
    ): BitmapDescriptor {
        val drawable = ContextCompat.getDrawable(context, vectorResId)!!
        val scale = context.resources.displayMetrics.density
        val widthPx = (widthDp * scale).toInt()
        val heightPx = (heightDp * scale).toInt()

        drawable.setBounds(0, 0, widthPx, heightPx)

        val bmp = createBitmap(widthPx, heightPx)
        val canvas = Canvas(bmp)
        drawable.draw(canvas)

        return BitmapDescriptorFactory.fromBitmap(bmp)
    }

    private fun makeUserBitmap(sizeDp: Int): Bitmap {
        val v = LayoutInflater.from(mapView.context).inflate(R.layout.custom_starting_point, null)
        val px = (sizeDp * mapView.context.resources.displayMetrics.density).toInt()
        v.measure(
            View.MeasureSpec.makeMeasureSpec(px, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(px, View.MeasureSpec.EXACTLY)
        )
        v.layout(0, 0, px, px)
        return createBitmap(px, px).also { bmp ->
            v.draw(Canvas(bmp))
        }
    }
}