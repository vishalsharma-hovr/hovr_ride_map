package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.ride.RideMapPolylineDecoder
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RideMapPolylineDecoderTest {
    @Test
    fun shouldSkipPolylineRedraw_whenPolylineUnchanged() {
        val polyline = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
        assertTrue(RideMapPolylineDecoder.shouldSkipPolylineRedraw(polyline, polyline))
    }

    @Test
    fun shouldSkipPolylineRedraw_falseWhenNoPreviousDraw() {
        assertFalse(RideMapPolylineDecoder.shouldSkipPolylineRedraw("abc", null))
    }

    @Test
    fun shouldSkipPolylineRedraw_falseWhenPolylineChanged() {
        assertFalse(
            RideMapPolylineDecoder.shouldSkipPolylineRedraw(
                "new_polyline",
                "old_polyline",
            ),
        )
    }
}
