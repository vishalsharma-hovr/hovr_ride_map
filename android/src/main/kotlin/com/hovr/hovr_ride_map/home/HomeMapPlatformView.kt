package com.hovr.hovr_ride_map.home

/**
 * Exposes a native Google-Map to Flutter via PlatformView.
 *
 * ───────────────────────────────────────────────────────────────
 * • Re-centers on demand  through    channel: "ride-view-channel"
 * • Draws / updates driver markers through "show-drivers-location-on-map"
 * • Tracks device location continuously via LocationManager
 * • Keeps first-fix zoom logic and user-gesture detection
 * ───────────────────────────────────────────────────────────────
 */


import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.location.Location
import android.util.Log
import android.view.View
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.hovr.hovr_ride_map.RideViewChannelHub
import com.hovr.hovr_ride_map.home.HomeMapMarkerManager
import com.hovr.hovr_ride_map.home.LocationManager
import com.google.android.gms.maps.*
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import com.hovr.hovr_ride_map.R

internal class HomeMapPlatformView(
    private val ctx: Context,
    messenger: BinaryMessenger
) : PlatformView,
    OnMapReadyCallback,
    DefaultLifecycleObserver {

    /* -------- native view -------- */
    private val mapView = MapView(ctx)

    /* -------- collaborators -------- */
    private val locationManager = LocationManager(ctx)
    private val markerManager = HomeMapMarkerManager(ctx) // for USER dot/starting marker

    /* -------- state -------- */
    private var googleMap: GoogleMap? = null
    private var firstFix = true
    private var carMarkers: CarMarkers? = null

    // FIX: Add flags to handle race conditions
    private var isMapReady = false
    private var pendingDriverUpdates: List<CarFix>? = null

    /* -------- Flutter channels -------- */
    private val driversChannel = MethodChannel(messenger, "show-drivers-location-on-map")
    private var rideViewHandlerRegistered = false

    private val rideViewHandler = MethodChannel.MethodCallHandler { call, result ->
        when (call.method) {
            "recenter-map" -> recenterMap(result)
            "driver-location-update" -> {
                val arg = call.arguments as? Map<*, *>
                val driverLat = arg?.get("lat") as? Double
                val driverLng = arg?.get("lng") as? Double
                println("DRIVER-LOCATION ${driverLat} , ${driverLng}")
                result.success("Driver location is shared!")
            }

            else -> result.notImplemented()
        }
    }

    init {
        initMapView()
        registerWithStack()
        initLocationUpdates()
    }

    /* ───────────────────────── MapView setup ───────────────────────── */
    private fun initMapView() {
        mapView.onCreate(null)               // no Bundle in PlatformViews
        mapView.getMapAsync(this)
    }

    override fun onMapReady(map: GoogleMap) {
        googleMap = map.apply {
            isBuildingsEnabled = false
            isIndoorEnabled = false
            isTrafficEnabled = false
            setOnCameraMoveStartedListener { reason ->
                if (reason == GoogleMap.OnCameraMoveStartedListener.REASON_GESTURE) {
                    firstFix = false
                }
            }
        }
        // Initialize the animator once the map is ready
        carMarkers = CarMarkers(map, getScaledCarIcon())

        isMapReady = true

        // FIX: Process any pending driver updates that arrived before map was ready
        pendingDriverUpdates?.let { fixes ->
            Log.d(TAG, "Processing ${fixes.size} pending driver updates")
            val nowMono = android.os.SystemClock.elapsedRealtime()
            carMarkers?.upsert(fixes, nowMono)
            pendingDriverUpdates = null
        }
        // Start device location tracking (for your user dot)
        locationManager.enableLocationTracking()
    }

    /* ───────────────────────── Flutter channels ───────────────────────── */
    private fun registerChannels() {
        if (!rideViewHandlerRegistered) {
            RideViewChannelHub.push(rideViewHandler)
            rideViewHandlerRegistered = true
        }
        driversChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "show-drivers" -> {
                    try {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        val nearby = args?.get("nearbyDrivers") as? List<*>

                        if (nearby.isNullOrEmpty()) {
                            Log.d(TAG, "Received empty driver list")
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        val fixes = parseNearbyDrivers(nearby)
                        Log.d(TAG, "Received ${fixes.size} drivers, mapReady=$isMapReady")

                        // FIX: Check if map is ready before updating
                        if (isMapReady && carMarkers != null) {
                            // Map is ready, update immediately
                            mapView.post {
                                val nowMono = android.os.SystemClock.elapsedRealtime()
                                carMarkers?.upsert(fixes, nowMono)
                            }
                        } else {
                            // FIX: Map not ready yet, queue the update
                            Log.d(TAG, "Map not ready, queuing ${fixes.size} driver updates")
                            pendingDriverUpdates = fixes
                        }

                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing drivers: ${e.message}", e)
                        result.error("PROCESSING_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

    }

    private fun clearChannels() {
        if (rideViewHandlerRegistered) {
            RideViewChannelHub.pop(rideViewHandler)
            rideViewHandlerRegistered = false
        }
        driversChannel.setMethodCallHandler(null)
    }

    private fun registerWithStack() {
        synchronized(stackLock) {
            instanceStack.addLast(this)
            registerChannels()
        }
    }

    private fun unregisterFromStack() {
        synchronized(stackLock) {
            val wasTop = instanceStack.lastOrNull() == this
            instanceStack.remove(this)
            if (wasTop) {
                clearChannels()
                instanceStack.lastOrNull()?.registerChannels()
            }
        }
    }

    /* ───────────────────────── Location updates ───────────────────────── */
    private fun initLocationUpdates() {
        locationManager.setLocationCallback { loc -> updateLocationOnMap(loc) }
    }

    private fun updateLocationOnMap(location: Location) {
        val pos = LatLng(location.latitude, location.longitude)

        googleMap?.let { map ->
            // USER marker (your own manager)
            markerManager.updateStartingMarker(map, pos)

            if (firstFix) {
                map.animateCamera(CameraUpdateFactory.newLatLngZoom(pos, 16.5f))
                firstFix = false
            }
        }
    }

    private fun recenterMap(result: MethodChannel.Result) {
        locationManager.getCurrentLocation { loc ->
            loc?.let {
                val pos = LatLng(it.latitude, it.longitude)
                googleMap?.animateCamera(CameraUpdateFactory.newLatLngZoom(pos, 16.5f))
                result.success(null)
            } ?: result.error("LOCATION_ERROR", "Unable to get current location", null)
        }
    }

    /* ───────────────────────── Helpers ───────────────────────── */
    private fun getScaledCarIcon(): BitmapDescriptor {
        val sizeDp = 32f
        val px = (sizeDp * mapView.resources.displayMetrics.density).toInt()
        val bmp = BitmapFactory.decodeResource(mapView.resources, R.drawable.ic_car)
        val scaled: Bitmap =
            if (bmp.width == px && bmp.height == px) bmp else Bitmap.createScaledBitmap(bmp, px, px, true)
        return BitmapDescriptorFactory.fromBitmap(scaled)
    }

    /* ───────────────────────── PlatformView contract ───────────────────────── */
    override fun getView(): View = mapView


    override fun dispose() {
        Log.d(TAG, "Disposing HomeViewGoogleMap")
        unregisterFromStack()
        isMapReady = false
        pendingDriverUpdates = null
        carMarkers = null
        locationManager.dispose()
        markerManager.dispose()
        mapView.onDestroy()
    }

    /* ───────────────────────── Lifecycle hooks (optional) ───────────────────────── */
    override fun onResume(owner: LifecycleOwner) {
        Log.d(TAG, "onResume")
        mapView.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        Log.d(TAG, "onPause")
        mapView.onPause()
    }

    companion object {
        private const val TAG = "HomeMapPlatformView"
        private val instanceStack = ArrayDeque<HomeMapPlatformView>()
        private val stackLock = Any()
    }
}
