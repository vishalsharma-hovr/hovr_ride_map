package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.shared.BearingSmoother
import com.hovr.hovr_ride_map.shared.calculateBearing
import com.hovr.hovr_ride_map.shared.getDynamicPadding
import com.hovr.hovr_ride_map.shared.normalizeDeg
import com.hovr.hovr_ride_map.shared.shortestDeltaDeg
import com.google.android.gms.maps.model.LatLng
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MapGeometryHelpersTest {
    @Test
    fun calculateBearing_north_is_zero() {
        val from = LatLng(0.0, 0.0)
        val to = LatLng(1.0, 0.0)
        val bearing = calculateBearing(from, to)
        assertEquals(0f, bearing, 0.5f)
    }

    @Test
    fun calculateBearing_east_is_ninety() {
        val from = LatLng(0.0, 0.0)
        val to = LatLng(0.0, 1.0)
        val bearing = calculateBearing(from, to)
        assertEquals(90f, bearing, 0.5f)
    }

    @Test
    fun getDynamicPadding_decreases_with_distance() {
        assertTrue(getDynamicPadding(1000f) > getDynamicPadding(30000f))
    }

    @Test
    fun bearingSmoother_wraps_across_zero() {
        val smoother = BearingSmoother(alpha = 1f)
        val first = smoother.apply(350f)
        val second = smoother.apply(10f)
        assertEquals(10f, second, 0.1f)
        assertEquals(350f, first, 0.1f)
    }

    @Test
    fun shortestDeltaDeg_across_antimeridian() {
        assertEquals(-20f, shortestDeltaDeg(10f, 350f), 0.01f)
        assertEquals(20f, shortestDeltaDeg(350f, 10f), 0.01f)
    }

    @Test
    fun normalizeDeg_wraps_negative() {
        assertEquals(270f, normalizeDeg(-90f), 0.01f)
    }
}
