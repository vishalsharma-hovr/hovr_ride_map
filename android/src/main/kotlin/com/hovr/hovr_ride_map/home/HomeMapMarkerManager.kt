package com.hovr.hovr_ride_map.home

import android.animation.ValueAnimator
import android.content.Context
import android.view.LayoutInflater
import android.view.animation.AccelerateDecelerateInterpolator
import com.hovr.hovr_ride_map.home.SnapToRoadsCallback
import com.hovr.hovr_ride_map.home.snapPathToRoads
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions
import kotlinx.coroutines.*
import com.hovr.hovr_ride_map.R
import com.hovr.hovr_ride_map.utils.MapViewUtils.createBitmapFromView
import androidx.core.graphics.createBitmap
import com.hovr.hovr_ride_map.utils.MapViewUtils.googleApiKey

// Updated main class with animation support
internal class HomeMapMarkerManager(private val context: Context) {

    private val startingPointView = LayoutInflater.from(context)
        .inflate(R.layout.custom_starting_point, null)

    private var startingPointBitmap: BitmapDescriptor? = null
    private var startingMarker: Marker? = null
    private var driverMarkers = mutableMapOf<String, DriverMarkerData>()
    private val carIconCache = mutableMapOf<Int, BitmapDescriptor>()
    private val activeAnimators = mutableMapOf<String, ValueAnimator>()

    private val lifecycleScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    fun updateStartingMarker(map: GoogleMap, location: LatLng) {
        startingMarker?.remove()
        startingMarker = map.addMarker(
            MarkerOptions()
                .position(location)
                .icon(getStartingPointIcon())
        )
    }

    fun displayDrivers(map: GoogleMap, drivers: List<*>) {
        if (drivers.isEmpty()) return

        lifecycleScope.launch {
            val processedDrivers = processDriverData(drivers)
            val coordinates = processedDrivers.map { it.second }

            snapPathToRoads(coordinates, googleApiKey(context), object : SnapToRoadsCallback {
                override fun onComplete(snappedPoints: List<LatLng>) {
                    updateDriverMarkersWithAnimation(map, processedDrivers, snappedPoints)
                }
            })
        }
    }

    private fun processDriverData(drivers: List<*>): List<Triple<String, LatLng, Map<*, *>>> {
        return drivers.mapIndexedNotNull { index, driver ->
            (driver as? Map<*, *>)?.let { map ->
                val id = map["driverId"]?.toString() ?: "driver_$index"
                val location = map["position"] as? Map<*, *>
                val lat = (location?.get("latitude") as? Number)?.toDouble()
                val lng = (location?.get("longitude") as? Number)?.toDouble()

                if (lat != null && lng != null) {
                    Triple(id, LatLng(lat, lng), map)
                } else null
            }
        }
    }

    private fun updateDriverMarkersWithAnimation(
        map: GoogleMap,
        processedDrivers: List<Triple<String, LatLng, Map<*, *>>>,
        snappedPoints: List<LatLng>
    ) {
        if (snappedPoints.size != processedDrivers.size) return

        val incomingIds = mutableSetOf<String>()

        processedDrivers.zip(snappedPoints).forEachIndexed { index, (driverData, snappedLatLng) ->
            val (id, originalLatLng, driverInfo) = driverData
            incomingIds += id

            val iconSize = calculateSizeForZoom(map.cameraPosition?.zoom ?: 10f)

            if (driverMarkers.containsKey(id)) {
                // Update existing marker with animation
                animateMarkerToPosition(map, id, snappedLatLng, iconSize, processedDrivers, index)
            } else {
                // Create new marker
                createNewDriverMarker(map, id, snappedLatLng, iconSize)
            }
        }

        removeStaleMarkers(incomingIds)
    }

    private fun createNewDriverMarker(
        map: GoogleMap,
        id: String,
        position: LatLng,
        iconSize: Int
    ) {
        val marker = map.addMarker(
            MarkerOptions()
                .position(position)
                .icon(getCarIcon(iconSize))
                .anchor(0.5f, 0.5f)
                .flat(true)
        )

        marker?.let {
            driverMarkers[id] = DriverMarkerData(
                marker = it,
                currentPosition = position
            )
        }
    }

    private fun animateMarkerToPosition(
        map: GoogleMap,
        driverId: String,
        targetPosition: LatLng,
        iconSize: Int,
        allDrivers: List<Triple<String, LatLng, Map<*, *>>>,
        currentIndex: Int
    ) {
        val markerData = driverMarkers[driverId] ?: return

        // Cancel existing animation
        activeAnimators[driverId]?.cancel()

        val startPosition = markerData.currentPosition

        // Calculate bearing based on movement direction
        val bearing = calculateProperBearing(startPosition, targetPosition, allDrivers, currentIndex)

        // Create smooth animation
        val animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 800L // Animation duration
            interpolator = AccelerateDecelerateInterpolator()

            addUpdateListener { animation ->
                val progress = animation.animatedValue as Float

                // Interpolate position
                val currentLat = startPosition.latitude +
                        (targetPosition.latitude - startPosition.latitude) * progress
                val currentLng = startPosition.longitude +
                        (targetPosition.longitude - startPosition.longitude) * progress
                val currentPosition = LatLng(currentLat, currentLng)

                // Interpolate bearing for smooth rotation
                val currentBearing = interpolateBearing(markerData.currentBearing, bearing, progress)

                // Update marker
                markerData.marker.apply {
                    position = currentPosition
                    rotation = currentBearing
                }

                markerData.currentPosition = currentPosition
                markerData.currentBearing = currentBearing
            }

            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationStart(animation: android.animation.Animator) {
                    markerData.isAnimating = true
                }

                override fun onAnimationEnd(animation: android.animation.Animator) {
                    markerData.isAnimating = false
                    markerData.previousPosition = startPosition
                    activeAnimators.remove(driverId)
                }

                override fun onAnimationCancel(animation: android.animation.Animator) {
                    markerData.isAnimating = false
                    activeAnimators.remove(driverId)
                }
            })
        }

        activeAnimators[driverId] = animator
        animator.start()
    }

    private fun calculateProperBearing(
        startPosition: LatLng,
        endPosition: LatLng,
        allDrivers: List<Triple<String, LatLng, Map<*, *>>>,
        currentIndex: Int
    ): Float {
        // Use actual movement direction
        return BearingCalculator.calculateRoadBearing(startPosition, endPosition, null)
    }

    private fun interpolateBearing(startBearing: Float, endBearing: Float, progress: Float): Float {
        var start = startBearing
        var end = endBearing

        // Handle bearing wraparound (e.g., 350° to 10°)
        val diff = end - start
        when {
            diff > 180f -> start += 360f
            diff < -180f -> end += 360f
        }

        val interpolated = start + (end - start) * progress
        return (interpolated % 360f + 360f) % 360f
    }

    private fun removeStaleMarkers(currentIds: Set<String>) {
        val staleIds = driverMarkers.keys - currentIds
        staleIds.forEach { staleId ->
            activeAnimators[staleId]?.cancel()
            activeAnimators.remove(staleId)
            driverMarkers.remove(staleId)?.marker?.remove()
        }
    }

    private fun getStartingPointIcon(): BitmapDescriptor {
        if (startingPointBitmap == null) {
            val bitmap = createBitmapFromView(startingPointView)
            startingPointBitmap = BitmapDescriptorFactory.fromBitmap(bitmap)
        }
        return startingPointBitmap!!
    }

    private fun getCarIcon(sizeDp: Int): BitmapDescriptor =
        carIconCache.getOrPut(sizeDp) {
            BitmapUtils.getBitmapDescriptorFromVector(
                context,
                R.drawable.car,
                sizeDp,
                sizeDp
            )
        }

    private fun calculateSizeForZoom(zoom: Float): Int = when {
        zoom >= 18f -> 50
        zoom >= 16f -> 45
        zoom >= 14f -> 40
        zoom >= 12f -> 30
        else -> 16
    }

    fun dispose() {
        lifecycleScope.cancel()

        // Cancel all active animations
        activeAnimators.values.forEach { it.cancel() }
        activeAnimators.clear()

        driverMarkers.values.forEach { it.marker.remove() }
        driverMarkers.clear()
        startingMarker?.remove()
        startingMarker = null
        carIconCache.clear()
        startingPointBitmap = null
    }

    // Helper function you'll need to implement for createBitmapFromView
    private fun createBitmapFromView(view: android.view.View): android.graphics.Bitmap {
        view.measure(
            android.view.View.MeasureSpec.makeMeasureSpec(0, android.view.View.MeasureSpec.UNSPECIFIED),
            android.view.View.MeasureSpec.makeMeasureSpec(0, android.view.View.MeasureSpec.UNSPECIFIED)
        )
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        val bitmap = createBitmap(view.measuredWidth, view.measuredHeight)
        val canvas = android.graphics.Canvas(bitmap)
        view.draw(canvas)
        return bitmap
    }
}


// Data class to store marker animation state
data class DriverMarkerData(
    val marker: Marker,
    var previousPosition: LatLng? = null,
    var currentPosition: LatLng,
    var targetPosition: LatLng? = null,
    var currentBearing: Float = 0f,
    var isAnimating: Boolean = false
)