package com.hovr.hovr_ride_map.ride

import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.hovr.hovr_ride_map.shared.calculateDistanceInMeters
import com.hovr.hovr_ride_map.shared.getDynamicPadding

/** Camera recenter strategies for [RideMapPlatformView]. */
internal object RideMapRecenter {
    data class State(
        val lastDriverLatLng: LatLng?,
        val carPosition: LatLng?,
        val startPosition: LatLng?,
        val destPosition: LatLng?,
        val lastDropoffLatLng: LatLng?,
        val lastPickupLatLng: LatLng?,
        val lastUserLatLng: LatLng?,
        val polylinePoints: List<LatLng>,
        val followZoom: Float,
    )

    fun applyFit(map: GoogleMap, fit: String?, state: State): Boolean {
        return when (fit) {
            "driverToDestination" -> fitDriverToDestination(map, state)
            "driverToPickup" -> fitDriverToPickup(map, state)
            else -> false
        }
    }

    fun fitPolylineStart(map: GoogleMap, state: State): Boolean {
        val firstPoint = state.polylinePoints.firstOrNull() ?: return false
        map.animateCamera(CameraUpdateFactory.newLatLngZoom(firstPoint, state.followZoom))
        return true
    }

    private fun fitDriverToDestination(map: GoogleMap, state: State): Boolean {
        val driver = state.lastDriverLatLng ?: state.carPosition ?: state.startPosition
        val destination = state.destPosition ?: state.lastDropoffLatLng ?: state.polylinePoints.lastOrNull()
        if (driver != null && destination != null) {
            animateBounds(map, driver, destination)
            return true
        }
        return fitFullPolyline(map, state)
    }

    private fun fitDriverToPickup(map: GoogleMap, state: State): Boolean {
        val driver = state.lastDriverLatLng
            ?: state.carPosition
            ?: state.startPosition
            ?: state.polylinePoints.firstOrNull()
        val pickup = state.lastPickupLatLng
            ?: state.destPosition
            ?: state.polylinePoints.lastOrNull()
        if (driver != null && pickup != null) {
            val builder = LatLngBounds.builder().include(driver).include(pickup)
            val spanMeters = calculateDistanceInMeters(driver, pickup)
            if (spanMeters < 50.0) {
                state.lastUserLatLng?.let { builder.include(it) }
            }
            val padding = getDynamicPadding(maxOf(spanMeters, 80f))
            map.animateCamera(CameraUpdateFactory.newLatLngBounds(builder.build(), padding))
            return true
        }
        if (pickup != null) {
            map.animateCamera(CameraUpdateFactory.newLatLngZoom(pickup, state.followZoom))
            return true
        }
        return fitFullPolyline(map, state)
    }

    private fun fitFullPolyline(map: GoogleMap, state: State): Boolean {
        if (state.polylinePoints.size < 2) return false
        val bounds = LatLngBounds.builder().apply {
            state.polylinePoints.forEach { include(it) }
        }.build()
        val padding = getDynamicPadding(
            calculateDistanceInMeters(state.polylinePoints.first(), state.polylinePoints.last())
        )
        map.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, padding))
        return true
    }

    private fun animateBounds(map: GoogleMap, a: LatLng, b: LatLng) {
        val bounds = LatLngBounds.builder().include(a).include(b).build()
        val padding = getDynamicPadding(calculateDistanceInMeters(a, b))
        map.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, padding))
    }
}
