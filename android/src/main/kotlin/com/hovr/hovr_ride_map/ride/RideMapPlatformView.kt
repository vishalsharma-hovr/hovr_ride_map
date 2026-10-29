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
import com.hovr.hovr_ride_map.shared.MapChromePolicy
import com.hovr.hovr_ride_map.shared.MapStylePolicy
import com.hovr.hovr_ride_map.shared.MapThemeColors
import com.hovr.hovr_ride_map.shared.MapThemeTint
import com.hovr.hovr_ride_map.ChannelArgParsers
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
import com.hovr.hovr_ride_map.home.CarFix
import com.hovr.hovr_ride_map.home.CarMarkers
import com.hovr.hovr_ride_map.model.StopLocation
import com.hovr.hovr_ride_map.route.RouteStopMarkerBitmap
import com.hovr.hovr_ride_map.route.RouteStopParser
import com.hovr.hovr_ride_map.shared.calculateBearing
import com.hovr.hovr_ride_map.shared.HovrCarIcon

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
    private var hasFittedCameraToRoute = false
    private var userHasInteractedWithMap = false
    private var currentIconSizeDp = -1
    private var destIconCached: BitmapDescriptor? = null
    // Colours the cached icons were drawn in; a theme change rebuilds them.
    private var iconCacheColors: MapThemeColors? = null

    private val userIconCache = mutableMapOf<Int, BitmapDescriptor>()

    private val activePolylines = mutableListOf<Polyline>()

    private var startMarker: Marker? = null
    private var destMarker: Marker? = null
    private var carMarker: Marker? = null
    /** Remaining path drawn on the map (driver → destination). */
    private var polylinePoints: List<LatLng> = emptyList()
    /** Full decoded route used to re-trim completed segments as the car moves. */
    private var sourceRoutePath: List<LatLng> = emptyList()
    private var currentPolylineIndex = 0
    private val activeMarkers = mutableListOf<Marker>()

    private val TAG = "drawRoute"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val tripDriverId = "trip-driver"
    private var tripCarMarkers: CarMarkers? = null
    private var tripCarFestiveVersion = -1
    private var tripCarTint: Int? = null

    private var pendingRoute: Pair<String, String?>? = null
    private var pendingPolylineString: String? = null
    private var pendingRouteForce: Boolean = false
    private var savedPolylineString: String? = null
    private var lastDrawnPolyline: String? = null

    private var mapViewReady = false
    private var pendingRecenterFit: String? = null
    private var shouldRestoreRoute = false
    private var hasRestoredRoute = false
    private var isAppInForeground = false
    private var currentTripId: String? = null
    private var routeExplicitlyCleared = false

    private var segmentBearings: FloatArray = floatArrayOf()
    private val bearingSmoother = BearingSmoother(alpha = 0.35f)
    private var followOffsetMeters = 60.0
    private var followTilt = 45f
    private var followZoom = 17f
    private var lastDriverLatLng: LatLng? = null
    private data class PendingDriverFix(val lat: Double, val lng: Double, val bearing: Float?)
    private var pendingDriverFix: PendingDriverFix? = null
    private var lastDropoffLatLng: LatLng? = null
    private var lastPickupLatLng: LatLng? = null
    private var lastUserLatLng: LatLng? = null
    private var stopsList: List<StopLocation> = emptyList()
    private val stopMarkers = mutableListOf<Marker>()

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
                    onMain { clearRouteStateAndOverlays() }
                    result.success(null)
                    return@MethodCallHandler
                }

                // Match iOS GlobalFlutterBridge: force clears prior route state, then applies.
                val force = ChannelArgParsers.boolFrom(arg, "force")
                onMain {
                    if (force) {
                        lastDrawnPolyline = null
                        clearRouteOverlays()
                    }
                    setRoute(args, "", force)
                }
                result.success(null)
            }

            "driver-location-update" -> {
                val arg = call.arguments as? Map<*, *>
                val coords = ChannelArgParsers.latLngFrom(arg)

                if (coords != null) {
                    val (driverLat, driverLng) = coords
                    onMain {
                        val bearing = ChannelArgParsers.bearingFrom(arg)
                        upsertTripDriver(driverLat, driverLng, bearing)
                        saveDriverLocationToPrefs(driverLat, driverLng, bearing)
                    }
                    result.success("Location received successfully!")
                } else {
                    result.error("INVALID_LOCATION", "Driver location missing", null)
                }
            }

            "drop-off-location" -> {
                val arg = call.arguments as? Map<*, *>
                val coords = ChannelArgParsers.latLngFrom(arg)
                if (coords != null) {
                    val (lat, lng) = coords
                    lastDropoffLatLng = LatLng(lat, lng)
                    onMain { refreshDropOffMarkerFromPolyline() }
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing dropoff lat/lng", null)
                }
            }

            "trip-stops" -> {
                val arg = call.arguments as? Map<*, *>
                stopsList = RouteStopParser.parse(arg?.get("stops"))
                onMain {
                    redrawStopMarkers()
                }
                result.success(null)
            }

            "pickup-location" -> {
                val arg = call.arguments as? Map<*, *>
                val coords = ChannelArgParsers.latLngFrom(arg)
                if (coords != null) {
                    val (lat, lng) = coords
                    lastPickupLatLng = LatLng(lat, lng)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing pickup lat/lng", null)
                }
            }

            "user-location" -> {
                val arg = call.arguments as? Map<*, *>
                val coords = ChannelArgParsers.latLngFrom(arg)
                if (coords != null) {
                    val (lat, lng) = coords
                    lastUserLatLng = LatLng(lat, lng)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing user lat/lng", null)
                }
            }

            "clear-route" -> {
                onMain { clearRouteStateAndOverlays() }
                result.success(null)
            }

            "clear-driver-location" -> {
                onMain { clearTripDriverMarkerAndPrefs() }
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

            "clear-pickup-user-markers" -> {
                onMain { clearPickupAndUserMarkers() }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    fun setRoute(polyline: String, eta: String?, force: Boolean = false) {
        routeExplicitlyCleared = false
        // Match iOS applyDriverRoute: force resets last-drawn so the next apply always paints.
        if (force) {
            lastDrawnPolyline = null
        }
        if (!force && RideMapPolylineDecoder.shouldSkipPolylineRedraw(polyline, lastDrawnPolyline)) {
            Log.d(TAG, "Skipping duplicate polyline draw")
            return
        }

        applySetRoute(polyline, eta, force)
    }

    private fun applySetRoute(
        polyline: String,
        eta: String?,
        force: Boolean,
    ) {
        savedPolylineString = polyline

        when {
            googleMap == null -> {
                pendingRoute = polyline to eta
                pendingPolylineString = polyline
                pendingRouteForce = force
                Log.d(TAG, "Map not ready yet; queued route len=${polyline.length}")
            }

            !mapViewReady -> {
                pendingPolylineString = polyline
                pendingRouteForce = force
                Log.d(TAG, "MapView not yet laid out; deferring route draw")
            }

            else -> {
                pendingRoute = null
                pendingPolylineString = null
                pendingRouteForce = false
                Log.d(TAG, "Drawing route directly — map & layout ready")
                drawRoute(polyline, force)
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
        sharedPrefs.edit()
            .remove("last_polyline")
            .remove("current_trip_id")
            .commit()
        currentTripId = null
        Log.d(TAG, "✅ Cleared saved route from SharedPreferences")
    }

    /** Single main-thread entry for route clear — mirrors iOS PolylineController.clearPolyline(). */
    private fun clearRouteStateAndOverlays() {
        routeExplicitlyCleared = true

        clearSavedRoute()

        savedPolylineString = null
        lastDrawnPolyline = null
        pendingPolylineString = null
        pendingRoute = null
        pendingRouteForce = false
        shouldRestoreRoute = false
        hasRestoredRoute = false
        hasFittedCameraToRoute = false
        userHasInteractedWithMap = false
        polylinePoints = emptyList()
        sourceRoutePath = emptyList()
        currentPolylineIndex = 0

        clearRouteOverlays()
    }

    init {
        mapView.onCreate(savedInstanceState)
        mapView.getMapAsync(this)

        // Prefs restore is for organic pause only. Stream-owned stages wait for
        // TripStream polylines so kill/reopen does not paint a stale pickup leg.
        if (!routeExplicitlyCleared && !isStreamOwnedTripStage(currentTripStage)) {
            val savedRoute = loadRouteFromPrefs()
            if (savedRoute != null && savedRoute.isNotEmpty()) {
                savedPolylineString = savedRoute
                lastDrawnPolyline = savedRoute
                Log.d(TAG, "🎯 Init: Route loaded from prefs")
            } else {
                Log.d(TAG, "Init: No saved route")
            }
        } else {
            Log.d(TAG, "Init: Skipping prefs load — cleared or stream-owned stage")
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

        RideViewChannelHub.pushRideMap(rideViewHandler)

        // Layout listener
        mapView.viewTreeObserver.addOnGlobalLayoutListener {
            if (!mapViewReady && mapView.width > 0 && mapView.height > 0) {
                mapViewReady = true
                Log.d(TAG, "🟢 MapView layout complete")

                val channelRoute = pendingPolylineString
                val prefsRoute =
                    if (!routeExplicitlyCleared && !isStreamOwnedTripStage(currentTripStage)) {
                        loadRouteFromPrefs()
                    } else {
                        null
                    }
                val routeToDraw = RideMapRouteClearState.resolveRouteToDraw(
                    pendingChannelRoute = channelRoute,
                    savedInMemoryRoute = if (isStreamOwnedTripStage(currentTripStage)) {
                        null
                    } else {
                        savedPolylineString ?: prefsRoute
                    },
                    routeExplicitlyCleared = routeExplicitlyCleared,
                )

                if (routeToDraw != null && routeToDraw.isNotEmpty()) {
                    val force = pendingRouteForce
                    Log.d(TAG, "📍 Drawing route after layout (len=${routeToDraw.length})")
                    pendingPolylineString = null
                    pendingRouteForce = false
                    savedPolylineString = routeToDraw

                    drawRoute(routeToDraw, force = force)
                } else {
                    Log.d(TAG, "No route to draw after layout")
                }

                flushPendingRecenter()
            }
        }
    }

    private fun handleAppPause() {
        Log.d(TAG, "🔴 handleAppPause")

        if (!routeExplicitlyCleared &&
            lastDrawnPolyline != null &&
            lastDrawnPolyline!!.isNotEmpty()
        ) {
            saveRouteToPrefs(lastDrawnPolyline!!)
            shouldRestoreRoute = true
            Log.d(TAG, "Marked for restoration")
        }
    }

    private fun handleAppResume() {
        Log.d(TAG, "🟢 handleAppResume")

        Handler(Looper.getMainLooper()).postDelayed({
            if (isStreamOwnedTripStage(currentTripStage)) {
                Log.d(TAG, "Skipping prefs resume restore — stream owns in-trip route")
                return@postDelayed
            }
            if (googleMap != null && mapViewReady) {
                val inMemoryRoute = lastDrawnPolyline ?: savedPolylineString
                val prefsRoute = loadRouteFromPrefs()
                val route = RideMapRouteClearState.resolveResumeRoute(
                    routeExplicitlyCleared = routeExplicitlyCleared,
                    shouldRestoreRoute = shouldRestoreRoute,
                    inMemoryRoute = inMemoryRoute,
                    prefsRoute = prefsRoute,
                )

                if (route != null && route.isNotEmpty()) {
                    val hasRoute = activePolylines.isNotEmpty() &&
                            route == lastDrawnPolyline

                    if (!hasRoute) {
                        Log.d(TAG, "✅ Restoring route (len=${route.length})")
                        hasRestoredRoute = true
                        shouldRestoreRoute = false

                        clearRouteOverlays()
                        drawRoute(route)
                    } else {
                        Log.d(TAG, "Route already drawn")
                        autoFitFullPolylineCamera()
                    }
                } else {
                    Log.d(TAG, "No route to restore")
                }
            } else {
                Log.d(TAG, "Map not ready (map=${googleMap != null}, ready=$mapViewReady)")
            }
        }, 600)
    }

    private fun clearRouteOverlays() {
        if (RideMapRouteClearState.shouldSkipRedundantOverlayClear(
                activePolylines.size,
                sourceRoutePath.size,
                polylinePoints.size,
            )
        ) {
            Log.d(TAG, "Skipping redundant route clear")
            return
        }

        try {
            activePolylines.forEach {
                try {
                    it.remove()
                } catch (_: Exception) {
                }
            }
            activePolylines.clear()
            lastDrawnPolyline = null
            Log.d(TAG, "✅ Route overlays cleared")
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing route overlays: ${e.message}")
        }
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

                clearStopMarkers()

                carMarker?.remove()
                carMarker = null

                clearTripDriverMarker()

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

    /** Trip car in the app theme's accent colour; a festive car keeps its own colours. */
    private fun getCarIcon(ctx: Context): BitmapDescriptor {
        tripCarFestiveVersion = HovrCarIcon.festiveVersion
        val tint = MapThemeColors.current.accent
        tripCarTint = tint
        return HovrCarIcon.bitmapDescriptor(ctx, tint = tint)
    }

    private fun dropIconCachesIfThemeChanged() {
        val colors = MapThemeColors.current
        if (colors == iconCacheColors) return
        iconCacheColors = colors
        destIconCached = null
        userIconCache.clear()
    }

    private fun getDestinationIcon(ctx: Context, sizeDp: Int = 56): BitmapDescriptor {
        dropIconCachesIfThemeChanged()
        return destIconCached ?: getBitmapDescriptorFromVector(
            ctx,
            R.drawable.circle_with_broad_green_background,
            sizeDp,
            sizeDp
        ).also {
            destIconCached = it
        }
    }

    companion object {
        private const val MIN_DENSE_ROUTE_POINTS = 4
        private const val SPARSE_POLYLINE_MAX_POINTS = 3
    }

    fun drawRoute(
        polyline: String,
        force: Boolean = false,
    ) {
        Log.d(TAG, "📍 drawRoute() CALLED - len=${polyline.length}")

        val map = googleMap
        if (map == null) {
            Log.w(TAG, "Map NULL")
            return
        }

        if (!mapViewReady) {
            Log.w(TAG, "MapView not ready")
            pendingPolylineString = polyline
            pendingRouteForce = force
            return
        }

        val decodedPath = try {
            RideMapPolylineDecoder.safeDecodeAny(polyline)
        } catch (e: Exception) {
            Log.e(TAG, "Decode failed: ${e.message}")
            emptyList()
        }

        if (decodedPath.size < 2) {
            Log.w(TAG, "Decoded path has too few points")
            return
        }

        // Never paint overview/2–3 point polylines — they look like a straight line.
        if (decodedPath.size <= SPARSE_POLYLINE_MAX_POINTS) {
            if (sourceRoutePath.size > decodedPath.size || activePolylines.isNotEmpty()) {
                Log.d(
                    TAG,
                    "Skipping sparse polyline (${decodedPath.size} pts); keeping denser route",
                )
                trimCompletedPolylineBehindDriver()
                return
            }
            Log.w(TAG, "Refusing to draw sparse polyline (${decodedPath.size} pts)")
            return
        }

        // Match iOS applyDriverRoute — no generation/stale skip; force always paints.
        if (!force &&
            sourceRoutePath.size >= MIN_DENSE_ROUTE_POINTS &&
            decodedPath.size <= SPARSE_POLYLINE_MAX_POINTS &&
            decodedPath.size < sourceRoutePath.size
        ) {
            Log.d(
                TAG,
                "Skipping sparse polyline replace (${decodedPath.size} pts); " +
                    "keeping denser route (${sourceRoutePath.size} pts)",
            )
            trimCompletedPolylineBehindDriver()
            return
        }

        if (!force &&
            RideMapPolylineDecoder.shouldSkipPolylineRedraw(polyline, lastDrawnPolyline) &&
            activePolylines.isNotEmpty()
        ) {
            Log.d(TAG, "Skipping unchanged driver route")
            maybeAutoFitCameraToFullPolylineOnce()
            return
        }

        val driverStart = resolvedDriverLatLng(decodedPath.first())
        // If trim fails (e.g. stale driver past the leg end), still draw the decoded path
        // so Android matches iOS visibility instead of aborting the update.
        val displayPath = RideMapRoutePath.routePathForDisplay(decodedPath, driverStart)
            ?: decodedPath.takeIf { it.size >= 2 }
        if (displayPath == null) {
            Log.w(TAG, "Display path has too few points")
            return
        }

        Log.d(TAG, "Applying driver route (${displayPath.size} pts)")

        routeExplicitlyCleared = false
        lastDrawnPolyline = polyline
        savedPolylineString = polyline
        saveRouteToPrefs(polyline)
        hasRestoredRoute = true

        userMarker?.remove()
        userMarker = null

        sourceRoutePath = decodedPath
        applyDisplayRoutePath(displayPath, map)
        placeRouteMarkersIfNeeded(displayPath, map)

        maybeAutoFitCameraToFullPolylineOnce()

        Log.d(TAG, "✅ Driver-anchored route applied")
    }

    private fun hasActiveRouteForCameraFit(): Boolean =
        sourceRoutePath.size >= 2 || polylinePoints.size >= 2

    /** One-time full-route camera fit when a polyline first appears (app open / restore). */
    private fun maybeAutoFitCameraToFullPolylineOnce() {
        if (userHasInteractedWithMap || hasFittedCameraToRoute) return
        if (!hasActiveRouteForCameraFit()) return
        if (autoFitFullPolylineCamera()) {
            hasFittedCameraToRoute = true
            Log.d(TAG, "One-time auto-fit to full polyline")
        }
    }

    /** Same camera behavior as tapping recenter during an active trip. */
    private fun autoFitFullPolylineCamera(): Boolean = performRecenter("fullPolyline")

    private fun resolvedDriverLatLng(fallback: LatLng): LatLng = lastDriverLatLng ?: fallback

    private fun updateActivePolyline(points: List<LatLng>, map: GoogleMap) {
        // Fixed screen-pixel width (not zoom-dependent); update path in place when present.
        if (activePolylines.isNotEmpty()) {
            activePolylines.forEach { it.points = points }
            return
        }

        activePolylines.forEach { it.remove() }
        activePolylines.clear()
        activePolylines += RideMapRouteStyle.addRoutePolyline(map, points, mapView.context)
    }

    private fun placeRouteMarkersIfNeeded(path: List<LatLng>, map: GoogleMap) {
        val end = RideMapRecenter.dropOffMarkerPosition(path, lastDropoffLatLng) ?: return
        destMarker?.remove()
        destMarker = map.addMarker(
            MarkerOptions()
                .position(end)
                .title("Destination")
                .icon(getDestinationIcon(mapView.context, sizeDp = 26))
                .visible(true)
                .anchor(0.5f, 0.5f)
                .zIndex(300f),
        )
        redrawStopMarkers()
    }

    /** Re-place drop-off on the current polyline end after channel updates. */
    private fun refreshDropOffMarkerFromPolyline() {
        val map = googleMap ?: return
        if (!mapViewReady) return
        if (polylinePoints.isEmpty()) return
        placeRouteMarkersIfNeeded(polylinePoints, map)
    }

    private fun clearStopMarkers() {
        stopMarkers.forEach {
            try {
                it.remove()
            } catch (_: Exception) {
            }
        }
        stopMarkers.clear()
    }

    private fun redrawStopMarkers() {
        val map = googleMap ?: return
        if (!mapViewReady) return
        clearStopMarkers()
        if (stopsList.isEmpty()) return

        stopsList.forEachIndexed { index, stop ->
            val position = LatLng(stop.latitude, stop.longitude)
            val stopIcon = BitmapDescriptorFactory.fromBitmap(
                RouteStopMarkerBitmap.create(mapView.context, index + 1),
            )
            map.addMarker(
                MarkerOptions()
                    .position(position)
                    .icon(stopIcon)
                    .anchor(0.5f, 0.5f)
                    .title(stop.address.ifBlank { "Stop ${index + 1}" })
                    .zIndex(250f),
            )?.also { marker ->
                stopMarkers.add(marker)
                activeMarkers.add(marker)
            }
        }
    }

    private fun hasTripDriverMarker(): Boolean {
        return lastDriverLatLng != null || tripCarMarkers?.marker(tripDriverId) != null
    }

    private var lastOffScreenRecenterAtMs = 0L
    private val offScreenRecenterMinIntervalMs = 1_500L

    private fun upsertTripDriver(lat: Double, lng: Double, bearing: Float? = null) {
        lastDriverLatLng = LatLng(lat, lng)
        val markers = tripCarMarkers
        if (markers == null) {
            pendingDriverFix = PendingDriverFix(lat, lng, bearing)
            Log.d(TAG, "Queued driver fix — map markers not ready yet")
            return
        }
        pendingDriverFix = null
        // The festive car and theme colour can change between driver updates.
        val carIconStale = HovrCarIcon.festiveVersion != tripCarFestiveVersion ||
            MapThemeColors.current.accent != tripCarTint
        if (carIconStale) markers.setIcon(getCarIcon(mapView.context))
        markers.upsert(
            listOf(
                CarFix(
                    id = tripDriverId,
                    lat = lat,
                    lng = lng,
                    bearingDeg = bearing,
                    speedMps = 12f,
                    timestampMs = System.currentTimeMillis(),
                ),
            ),
        )
        trimCompletedPolylineBehindDriver()
        maybeZoomOutWhenDriverLeavesScreen()
    }

    /**
     * Drops the completed route behind the car so only the remaining path is drawn.
     */
    private fun trimCompletedPolylineBehindDriver() {
        val map = googleMap ?: return
        if (!mapViewReady) return
        val driver = lastDriverLatLng ?: return
        if (sourceRoutePath.size < 2) return

        val displayPath = RideMapRoutePath.routePathForDisplay(sourceRoutePath, driver)
            ?: return
        if (displayPath.size == polylinePoints.size &&
            displayPath.firstOrNull() == polylinePoints.firstOrNull() &&
            displayPath.lastOrNull() == polylinePoints.lastOrNull()
        ) {
            return
        }
        applyDisplayRoutePath(displayPath, map)
    }

    private fun applyDisplayRoutePath(displayPath: List<LatLng>, map: GoogleMap) {
        polylinePoints = displayPath
        currentPolylineIndex = 0
        bearingSmoother.reset()
        segmentBearings = if (displayPath.size >= 2) {
            FloatArray(displayPath.size) { i ->
                if (i < displayPath.size - 1) {
                    calculateBearing(displayPath[i], displayPath[i + 1])
                } else {
                    calculateBearing(displayPath[i - 1], displayPath[i])
                }
            }
        } else {
            floatArrayOf(0f)
        }
        updateActivePolyline(displayPath, map)
    }

    /**
     * If the car drifts outside the camera frustum, expand the viewport to keep
     * driver + destination (route end) on screen.
     */
    private fun maybeZoomOutWhenDriverLeavesScreen() {
        val map = googleMap ?: return
        if (!mapViewReady) return
        if (userHasInteractedWithMap) return

        val now = System.currentTimeMillis()
        if (now - lastOffScreenRecenterAtMs < offScreenRecenterMinIntervalMs) return

        val fitted = RideMapRecenter.ensureDriverVisible(
            map,
            buildRecenterState(),
            mapView.width,
            mapView.height,
        )
        if (fitted) {
            lastOffScreenRecenterAtMs = now
            Log.d(TAG, "Zoomed out — driver left the visible map region")
        }
    }

    private fun seedTripDriverAt(position: LatLng, bearing: Float) {
        upsertTripDriver(position.latitude, position.longitude, bearing)
    }

    private fun clearTripDriverMarker() {
        tripCarMarkers?.remove(tripDriverId)
        lastDriverLatLng = null
    }

    private fun clearTripDriverMarkerAndPrefs() {
        pendingDriverFix = null
        clearTripDriverMarker()
        clearSavedDriverLocation()
    }

    private fun saveDriverLocationToPrefs(lat: Double, lng: Double, bearing: Float?) {
        try {
            val editor = sharedPrefs.edit()
                .putString("last_driver_lat", lat.toString())
                .putString("last_driver_lng", lng.toString())
            if (bearing != null) {
                editor.putString("last_driver_bearing", bearing.toString())
            } else {
                editor.remove("last_driver_bearing")
            }
            editor.apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save driver location: ${e.message}")
        }
    }

    private fun loadDriverLocationFromPrefs(): Triple<Double, Double, Float?>? {
        return try {
            val lat = sharedPrefs.getString("last_driver_lat", null)?.toDoubleOrNull()
            val lng = sharedPrefs.getString("last_driver_lng", null)?.toDoubleOrNull()
            if (lat == null || lng == null) return null
            val bearing = sharedPrefs.getString("last_driver_bearing", null)?.toFloatOrNull()
            Triple(lat, lng, bearing)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load driver location: ${e.message}")
            null
        }
    }

    private fun clearSavedDriverLocation() {
        sharedPrefs.edit()
            .remove("last_driver_lat")
            .remove("last_driver_lng")
            .remove("last_driver_bearing")
            .apply()
    }

    private fun followStartMarker(currentBearing: Float? = null) {
        if (userHasInteractedWithMap) return
        val map = googleMap ?: return
        val tripMarker = tripCarMarkers?.marker(tripDriverId)
        val m = tripMarker ?: startMarker ?: carMarker ?: return

        val bearing = currentBearing ?: tripMarker?.rotation ?: m.rotation

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
        RideViewChannelHub.popRideMap(rideViewHandler)
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
            uiSettings.isZoomGesturesEnabled = true
            uiSettings.isScrollGesturesEnabled = true
            uiSettings.isTiltGesturesEnabled = true
            uiSettings.isRotateGesturesEnabled = true

            setOnCameraMoveStartedListener { reason ->
                if (reason == GoogleMap.OnCameraMoveStartedListener.REASON_GESTURE) {
                    userHasInteractedWithMap = true
                }
            }

            MapStylePolicy.attach(this, mapView.context, R.raw.hovr_maps_style)
            MapChromePolicy.apply(this)
        }

        tripCarMarkers = CarMarkers(map, getCarIcon(mapView.context))

        pendingDriverFix?.let { (lat, lng, bearing) ->
            upsertTripDriver(lat, lng, bearing)
        } ?: loadDriverLocationFromPrefs()?.let { (lat, lng, bearing) ->
            upsertTripDriver(lat, lng, bearing)
        }

        startLocationUpdates()

        if (!routeExplicitlyCleared && !isStreamOwnedTripStage(currentTripStage)) {
            val savedRoute = loadRouteFromPrefs()
            if (savedRoute != null && savedRoute.isNotEmpty()) {
                if (savedPolylineString == null || savedPolylineString!!.isEmpty()) {
                    Log.d(TAG, "💾 Loading from SharedPreferences")
                    savedPolylineString = savedRoute
                    lastDrawnPolyline = savedRoute
                }
            }
        } else {
            Log.d(TAG, "onMapReady: Skipping prefs load — cleared or stream-owned stage")
        }

        val channelRoute = pendingRoute?.first ?: pendingPolylineString
        val routeToDraw = RideMapRouteClearState.resolveRouteToDraw(
            pendingChannelRoute = channelRoute,
            savedInMemoryRoute = if (isStreamOwnedTripStage(currentTripStage)) null else savedPolylineString,
            routeExplicitlyCleared = routeExplicitlyCleared,
        )

        if (routeToDraw != null && routeToDraw.isNotEmpty()) {
            Log.d(TAG, "🗺️ Has route (len=${routeToDraw.length})")

            if (mapViewReady) {
                Log.d(TAG, "Drawing now")
                val force = pendingRouteForce
                pendingRoute = null
                pendingPolylineString = null
                pendingRouteForce = false
                hasRestoredRoute = true
                drawRoute(routeToDraw, force = force)
            } else {
                Log.d(TAG, "Waiting for layout")
                pendingPolylineString = routeToDraw
            }
        } else {
            Log.d(TAG, "No route")
        }

        when (val stage = currentTripStage) {
            null -> if (routeToDraw.isNullOrEmpty() && !userHasInteractedWithMap) moveToUserLocation()
            else -> applyTripStage(stage)
        }
    }

    private fun isStreamOwnedTripStage(stage: String?): Boolean =
        stage == "headingToDestination" ||
            stage == "meetAtPickup" ||
            stage == "driverWaitingAtPickup"

    private fun applyTripStage(stage: String) {
        if (stage == lastAppliedTripStage) return
        lastAppliedTripStage = stage
        onMain {
            // Match iOS TripStageController sink: only invalidate last-drawn so the
            // next stream polyline reapplies. Do not clear overlays (that raced draws).
            val replayStages = setOf(
                "headingToDestination",
                "meetAtPickup",
                "driverWaitingAtPickup",
            )
            if (stage in replayStages) {
                lastDrawnPolyline = null
                hasFittedCameraToRoute = false
            }
            if (stage == "headingToDestination") {
                clearPickupAndUserMarkers()
            }
            Log.d(TAG, "Applied trip stage: $stage")
        }
    }

    private fun clearPickupAndUserMarkers() {
        lastPickupLatLng = null
        lastUserLatLng = null
        userMarker?.remove()
        userMarker = null
        Log.d(TAG, "Cleared pickup/user markers for heading stage")
    }

    @SuppressLint("MissingPermission")
    private fun moveToUserLocation(zoom: Float = 15f) {
        if (currentTripStage == "headingToDestination") return
        if (userHasInteractedWithMap) return
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
        carPosition = tripCarMarkers?.marker(tripDriverId)?.position ?: carMarker?.position,
        startPosition = startMarker?.position,
        destPosition = destMarker?.position,
        lastDropoffLatLng = lastDropoffLatLng,
        lastPickupLatLng = lastPickupLatLng,
        lastUserLatLng = lastUserLatLng,
        polylinePoints = polylinePoints,
        fullRoutePoints = sourceRoutePath,
        followZoom = followZoom,
    )

    private fun performRecenter(fit: String?): Boolean {
        val map = googleMap ?: return false
        if (!mapViewReady) return false

        userHasInteractedWithMap = false

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

    private fun getUserIcon(sizeDp: Int): BitmapDescriptor {
        dropIconCachesIfThemeChanged()
        return userIconCache.getOrPut(sizeDp) {
            BitmapDescriptorFactory.fromBitmap(makeUserBitmap(sizeDp))
        }
    }

    private fun getBitmapDescriptorFromVector(
        context: Context, vectorResId: Int, widthDp: Int, heightDp: Int
    ): BitmapDescriptor {
        val drawable = ContextCompat.getDrawable(context, vectorResId)!!
        MapThemeTint.rings(drawable)
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
        MapThemeTint.applyToStartingPoint(v)
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