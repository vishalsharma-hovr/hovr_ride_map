package com.hovr.hovr_ride_map

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Before
import org.junit.Test

class RideViewChannelHubTest {

    @Before
    fun resetHub() {
        RideViewChannelHub.resetForTest()
    }

    @Test
    fun capturePending_driverLocation_acceptsIntegerCoordinates() {
        RideViewChannelHub.capturePending(
            MethodCall(
                "driver-location-update",
                mapOf("lat" to 43, "lng" to -79, "bearing" to 90),
            ),
        )

        val pending = RideViewChannelHub.pendingDriverLocation
        assertNotNull(pending)
        assertEquals(43.0, pending!!.lat, 0.0)
        assertEquals(-79.0, pending.lng, 0.0)
        assertEquals(90f, pending.bearing)
    }

    @Test
    fun capturePending_polyline_storesForceFlag() {
        RideViewChannelHub.capturePending(
            MethodCall(
                "polylines-channel",
                mapOf("polyline" to "encoded", "force" to true),
            ),
        )

        val pending = RideViewChannelHub.pendingPolyline
        assertNotNull(pending)
        assertEquals("encoded", pending!!.polyline)
        assertEquals(true, pending.force)
    }

    @Test
    fun applyClearPending_clearRoute_clearsBufferedState() {
        RideViewChannelHub.capturePending(
            MethodCall("polylines-channel", mapOf("polyline" to "abc")),
        )
        RideViewChannelHub.capturePending(
            MethodCall("driver-location-update", mapOf("lat" to 1.0, "lng" to 2.0)),
        )

        RideViewChannelHub.applyClearPending("clear-route")

        assertNull(RideViewChannelHub.pendingPolyline)
        assertNull(RideViewChannelHub.pendingDriverLocation)
    }

    @Test
    fun polylinesPreferRideMap_evenWhenHomeMapIsOnTop() {
        val home = stubHandler()
        val ride = stubHandler()

        RideViewChannelHub.push(home)
        RideViewChannelHub.pushRideMap(ride)

        assertSame(ride, RideViewChannelHub.targetHandlerForTest("polylines-channel"))
        assertSame(ride, RideViewChannelHub.targetHandlerForTest("driver-location-update"))
        // Recenter still uses the top generic handler (home / preview).
        assertSame(home, RideViewChannelHub.targetHandlerForTest("recenter-map"))
    }

    private fun stubHandler(): MethodChannel.MethodCallHandler =
        MethodChannel.MethodCallHandler { _, result -> result.success(null) }
}
