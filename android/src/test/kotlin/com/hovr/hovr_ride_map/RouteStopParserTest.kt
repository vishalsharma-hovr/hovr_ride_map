package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.route.RouteStopParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RouteStopParserTest {
    @Test
    fun parse_emptyOrNull_returnsEmpty() {
        assertTrue(RouteStopParser.parse(null).isEmpty())
        assertTrue(RouteStopParser.parse(emptyList<Any>()).isEmpty())
        assertTrue(RouteStopParser.parse("not-a-list").isEmpty())
    }

    @Test
    fun parse_validStops_mapsFields() {
        val stops = RouteStopParser.parse(
            listOf(
                mapOf(
                    "latitude" to 43.65,
                    "longitude" to -79.38,
                    "address" to "Stop A",
                ),
                mapOf(
                    "latitude" to 43.7,
                    "longitude" to -79.4,
                    "address" to "Stop B",
                ),
            ),
        )
        assertEquals(2, stops.size)
        assertEquals(43.65, stops[0].latitude, 0.0)
        assertEquals(-79.38, stops[0].longitude, 0.0)
        assertEquals("Stop A", stops[0].address)
        assertEquals("Stop B", stops[1].address)
    }

    @Test
    fun parse_acceptsNumberTypes_andSkipsZeroCoords() {
        val stops = RouteStopParser.parse(
            listOf(
                mapOf("latitude" to 43, "longitude" to -79, "address" to "Int coords"),
                mapOf("latitude" to 0.0, "longitude" to 0.0, "address" to "Empty"),
                mapOf("latitude" to 43.1f, "longitude" to -79.1f, "address" to "Float"),
            ),
        )
        assertEquals(2, stops.size)
        assertEquals("Int coords", stops[0].address)
        assertEquals("Float", stops[1].address)
    }
}
