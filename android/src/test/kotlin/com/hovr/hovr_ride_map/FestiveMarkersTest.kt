package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.shared.FestiveMarkers
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FestiveMarkersTest {
    private val png = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47)

    @Test
    fun parse_readsEveryMarker() {
        val specs = FestiveMarkers.parse(
            mapOf("markers" to listOf(mapOf("lat" to 43.65, "lng" to -79.38, "png" to png))),
        )
        assertEquals(1, specs.size)
        assertEquals(43.65, specs[0].lat, 0.0)
        assertEquals(-79.38, specs[0].lng, 0.0)
        assertArrayEquals(png, specs[0].png)
    }

    @Test
    fun parse_emptyListClears() {
        assertTrue(FestiveMarkers.parse(mapOf("markers" to emptyList<Any>())).isEmpty())
    }

    @Test
    fun parse_skipsBrokenEntries() {
        val specs = FestiveMarkers.parse(
            mapOf(
                "markers" to listOf(
                    mapOf("lat" to 43.65, "png" to png), // no lng
                    mapOf("lat" to 43.65, "lng" to -79.38), // no image
                    mapOf("lat" to 43.65, "lng" to -79.38, "png" to ByteArray(0)), // empty image
                    "not a map",
                ),
            ),
        )
        assertTrue(specs.isEmpty())
    }

    @Test
    fun parse_capsTheCount() {
        val one = mapOf("lat" to 1.0, "lng" to 2.0, "png" to png)
        val specs = FestiveMarkers.parse(mapOf("markers" to List(FestiveMarkers.MAX_MARKERS + 5) { one }))
        assertEquals(FestiveMarkers.MAX_MARKERS, specs.size)
    }
}
