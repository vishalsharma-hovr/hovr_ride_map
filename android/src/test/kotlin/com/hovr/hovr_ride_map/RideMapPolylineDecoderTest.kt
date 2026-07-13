package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.ride.RideMapPolylineDecoder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RideMapPolylineDecoderTest {
    /** Classic encoded polyline used across Google Maps / iOS MapGeometryHelpersTests. */
    private val samplePolyline = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"

    @Test
    fun sanitizeEncoded_matchesIosCleaning() {
        assertEquals(
            samplePolyline,
            RideMapPolylineDecoder.sanitizeEncoded("  \"$samplePolyline\"  "),
        )
        assertEquals(
            samplePolyline,
            RideMapPolylineDecoder.sanitizeEncoded("'$samplePolyline'"),
        )
    }

    @Test
    fun safeDecodeAny_decodesGoogleSampleLikeIosGmsPath() {
        val points = RideMapPolylineDecoder.safeDecodeAny(samplePolyline)
        assertTrue(points.size > 2)
        // First point of the classic Google sample polyline.
        assertEquals(38.5, points.first().latitude, 0.01)
        assertEquals(-120.2, points.first().longitude, 0.01)
    }

    @Test
    fun safeDecodeAny_stripsQuotesBeforeDecode() {
        val points = RideMapPolylineDecoder.safeDecodeAny("\"$samplePolyline\"")
        assertTrue(points.size > 2)
    }

    @Test
    fun safeDecodeAny_emptyAfterSanitize() {
        assertTrue(RideMapPolylineDecoder.safeDecodeAny("   ").isEmpty())
        assertTrue(RideMapPolylineDecoder.safeDecodeAny("\"\"").isEmpty())
    }

    @Test
    fun shouldSkipPolylineRedraw_whenPolylineUnchanged() {
        assertTrue(RideMapPolylineDecoder.shouldSkipPolylineRedraw(samplePolyline, samplePolyline))
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
