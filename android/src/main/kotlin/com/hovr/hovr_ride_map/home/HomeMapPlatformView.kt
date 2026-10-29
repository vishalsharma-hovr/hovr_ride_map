package com.hovr.hovr_ride_map.home

/**
 * Exposes a native Google-Map to Flutter via PlatformView.
 *
 * ───────────────────────────────────────────────────────────────
 * • Re-centers on demand  through    channel: "ride-view-channel"
 * • Draws / updates driver markers through "show-drivers-location-on-map"
 * • Native blue-dot via isMyLocationEnabled (SDK-managed)
 * • Tracks device location via LocationManager for camera first-fix / recenter
 * • Keeps first-fix zoom logic and user-gesture detection
 * ───────────────────────────────────────────────────────────────
 */

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.location.Location
import android.util.Log
import android.view.View
import androidx.core.app.ActivityCompat
import com.hovr.hovr_ride_map.R
import com.hovr.hovr_ride_map.RideViewChannelHub
import com.hovr.hovr_ride_map.shared.HovrCarIcon
import com.hovr.hovr_ride_map.shared.MapChromePolicy
import com.hovr.hovr_ride_map.shared.MapStylePolicy
import com.hovr.hovr_ride_map.shared.MapThemeColors
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

internal class HomeMapPlatformView(
    private val ctx: Context,
    messenger: BinaryMessenger,
    creationParams: Map<*, *>? = null,
) : PlatformView,
    OnMapReadyCallback {

    private val initialLatitude = creationParams?.get("initialLatitude") as? Double
    private val initialLongitude = creationParams?.get("initialLongitude") as? Double

    /* -------- native view -------- */
    private val mapView = MapView(ctx)

    /* -------- collaborators -------- */
    private val locationManager = LocationManager(ctx)

    /* -------- state -------- */
    private var googleMap: GoogleMap? = null
    private var firstFix = true
    private var carMarkers: CarMarkers? = null
    private var carIconTint: Int? = null
    private var carIconFestiveVersion = -1

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
        setupMapViewLifecycle()
    }

    /* ───────────────────────── MapView setup ───────────────────────── */
    private fun initMapView() {
        mapView.onCreate(null)
        mapView.getMapAsync(this)
    }

    private fun setupMapViewLifecycle() {
        mapView.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                Log.d(TAG, "View attached")
                try {
                    mapView.onStart()
                    mapView.onResume()
                    locationManager.resumeTracking()
                    enableMyLocationLayer()
                } catch (e: Exception) {
                    Log.e(TAG, "Error resuming map view: ${e.message}")
                }
            }

            override fun onViewDetachedFromWindow(v: View) {
                Log.d(TAG, "View detached")
                try {
                    mapView.onPause()
                    mapView.onStop()
                } catch (e: Exception) {
                    Log.e(TAG, "Error pausing map view: ${e.message}")
                }
            }
        })
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
        MapChromePolicy.apply(map)
        MapStylePolicy.attach(map, mapView.context, R.raw.hovr_maps_style)

        carMarkers = CarMarkers(map, themedCarIcon())
        isMapReady = true
        enableMyLocationLayer()

        pendingDriverUpdates?.let { fixes ->
            Log.d(TAG, "Processing ${fixes.size} pending driver updates")
            val nowMono = android.os.SystemClock.elapsedRealtime()
            carMarkers?.upsert(fixes, nowMono)
            pendingDriverUpdates = null
        }

        val hasInitialCoords = initialLatitude != null && initialLongitude != null &&
            (initialLatitude != 0.0 || initialLongitude != 0.0)
        if (hasInitialCoords) {
            val pos = LatLng(initialLatitude!!, initialLongitude!!)
            map.moveCamera(CameraUpdateFactory.newLatLngZoom(pos, 16.5f))
            firstFix = false
        }

        locationManager.getCurrentLocation { loc ->
            loc?.let { updateLocationOnMap(it) }
            locationManager.enableLocationTracking()
        }
    }

    @SuppressLint("MissingPermission")
    private fun enableMyLocationLayer() {
        if (!hasLocationPermission()) return
        googleMap?.isMyLocationEnabled = true
    }

    private fun hasLocationPermission(): Boolean =
        ActivityCompat.checkSelfPermission(
            ctx,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

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

                        if (isMapReady && carMarkers != null) {
                            mapView.post {
                                val nowMono = android.os.SystemClock.elapsedRealtime()
                                refreshCarIconIfThemeChanged()
                                carMarkers?.upsert(fixes, nowMono)
                            }
                        } else {
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
    /** Car marker in the app theme's accent colour (light/dark/festive). */
    private fun themedCarIcon(): BitmapDescriptor {
        val tint = MapThemeColors.current.accent
        carIconTint = tint
        carIconFestiveVersion = HovrCarIcon.festiveVersion
        return HovrCarIcon.bitmapDescriptor(mapView.context, tint = tint)
    }

    /** Theme changes arrive between driver updates, so recolour on the next one. */
    private fun refreshCarIconIfThemeChanged() {
        val changed = MapThemeColors.current.accent != carIconTint ||
            HovrCarIcon.festiveVersion != carIconFestiveVersion
        if (changed) carMarkers?.setIcon(themedCarIcon())
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
        mapView.onDestroy()
    }

    companion object {
        private const val TAG = "HomeMapPlatformView"
        private val instanceStack = ArrayDeque<HomeMapPlatformView>()
        private val stackLock = Any()
    }
}
