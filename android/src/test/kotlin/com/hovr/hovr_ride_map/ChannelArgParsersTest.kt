package com.hovr.hovr_ride_map

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ChannelArgParsersTest {

    @Test
    fun latLngFrom_acceptsDoubleValues() {
        val result = ChannelArgParsers.latLngFrom(mapOf("lat" to 43.65, "lng" to -79.38))
        assertEquals(43.65 to -79.38, result)
    }

    @Test
    fun latLngFrom_acceptsIntegerValues() {
        val result = ChannelArgParsers.latLngFrom(mapOf("lat" to 43, "lng" to -79))
        assertEquals(43.0 to -79.0, result)
    }

    @Test
    fun latLngFrom_rejectsMissingKeys() {
        assertNull(ChannelArgParsers.latLngFrom(mapOf("lat" to 43.0)))
    }
}
