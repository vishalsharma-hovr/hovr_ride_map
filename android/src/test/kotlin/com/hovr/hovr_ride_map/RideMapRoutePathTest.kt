package com.hovr.hovr_ride_map

import com.google.android.gms.maps.model.LatLng
import com.hovr.hovr_ride_map.ride.RideMapPolylineDecoder
import com.hovr.hovr_ride_map.ride.RideMapRoutePath
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RideMapRoutePathTest {
    private val samplePolyline = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"

    @Test
    fun closestIndex_findsNearestVertex() {
        val path = RideMapPolylineDecoder.safeDecodeAny(samplePolyline)
        assertTrue(path.size > 2)
        val target = path[1]
        assertEquals(1, RideMapRoutePath.closestIndex(path, target))
    }

    @Test
    fun trimmedPath_startsAtDriver() {
        val path = RideMapPolylineDecoder.safeDecodeAny(samplePolyline)
        assertTrue(path.size > 2)
        val driver = path[1]
        val trimmed = RideMapRoutePath.trimmedPath(path, driver)
        assertNotNull(trimmed)
        assertEquals(driver.latitude, trimmed!!.first().latitude, 0.00001)
        assertEquals(driver.longitude, trimmed.first().longitude, 0.00001)
    }

    @Test
    fun routePathForDisplay_usesStreamPathWhenDriverNearStart() {
        val path = RideMapPolylineDecoder.safeDecodeAny(samplePolyline)
        assertTrue(path.size > 1)
        val display = RideMapRoutePath.routePathForDisplay(path, path.first())
        assertNotNull(display)
        assertEquals(path.size, display!!.size)
    }

    @Test
    fun trimmedPath_returnsNullForSinglePointPath() {
        val single = listOf(LatLng(1.0, 1.0))
        assertNull(RideMapRoutePath.trimmedPath(single, LatLng(1.0, 1.0)))
    }
}
