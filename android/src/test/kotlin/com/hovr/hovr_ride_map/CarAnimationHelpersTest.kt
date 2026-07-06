package com.hovr.hovr_ride_map

import com.google.android.gms.maps.model.LatLng
import com.hovr.hovr_ride_map.home.calculateAnimationDuration
import com.hovr.hovr_ride_map.home.distanceMeters
import com.hovr.hovr_ride_map.home.movementHeading
import com.hovr.hovr_ride_map.home.slerpLatLng
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CarAnimationHelpersTest {
    @Test
    fun calculateAnimationDuration_clampsToReasonableRange() {
        val duration = calculateAnimationDuration(
            distanceMeters = 50.0,
            speedMps = 10f,
            previousSpeedMps = 10f,
            timeSinceLastUpdateMs = 2000L,
        )
        assertTrue(duration in 150L..6000L)
    }

    @Test
    fun slerpLatLng_midpoint_betweenTwoPoints() {
        val a = LatLng(37.0, -122.0)
        val b = LatLng(37.1, -122.1)
        val mid = slerpLatLng(a, b, 0.5f)
        assertTrue(distanceMeters(a, mid) < distanceMeters(a, b))
        assertTrue(distanceMeters(mid, b) < distanceMeters(a, b))
    }

    @Test
    fun movementHeading_returnsNullForMicroMoves() {
        val a = LatLng(37.0, -122.0)
        val b = LatLng(37.000001, -122.000001)
        assertEquals(null, movementHeading(a, b))
    }

    @Test
    fun movementHeading_east_isNinetyDegrees() {
        val from = LatLng(37.0, -122.0)
        val to = LatLng(37.0, -121.99)
        val heading = movementHeading(from, to)
        assertEquals(90f, heading!!, 5f)
    }
}
