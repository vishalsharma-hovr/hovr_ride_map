package com.hovr.hovr_ride_map

import com.google.android.gms.maps.model.LatLng
import com.hovr.hovr_ride_map.ride.RideMapRecenter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RideMapRecenterTest {
    private val driver = LatLng(37.0, -122.0)
    private val pickup = LatLng(37.1, -122.1)
    private val dropoff = LatLng(37.2, -122.2)
    private val polylineStart = LatLng(36.9, -121.9)
    private val polylineEnd = LatLng(37.3, -122.3)

    private fun baseState(
        lastDriverLatLng: LatLng? = null,
        carPosition: LatLng? = null,
        startPosition: LatLng? = null,
        destPosition: LatLng? = null,
        lastDropoffLatLng: LatLng? = null,
        lastPickupLatLng: LatLng? = null,
        polylinePoints: List<LatLng> = listOf(polylineStart, polylineEnd),
    ) = RideMapRecenter.State(
        lastDriverLatLng = lastDriverLatLng,
        carPosition = carPosition,
        startPosition = startPosition,
        destPosition = destPosition,
        lastDropoffLatLng = lastDropoffLatLng,
        lastPickupLatLng = lastPickupLatLng,
        lastUserLatLng = null,
        polylinePoints = polylinePoints,
        followZoom = 17f,
    )

    @Test
    fun resolveDriver_prefersLastDriverLatLng() {
        val state = baseState(
            lastDriverLatLng = driver,
            carPosition = LatLng(0.0, 0.0),
            startPosition = LatLng(1.0, 1.0),
        )
        assertEquals(driver, RideMapRecenter.resolveDriver(state))
    }

    @Test
    fun resolveDriver_fallsBackThroughCarStartAndPolyline() {
        assertEquals(
            LatLng(1.0, 1.0),
            RideMapRecenter.resolveDriver(baseState(carPosition = LatLng(1.0, 1.0))),
        )
        assertEquals(
            LatLng(2.0, 2.0),
            RideMapRecenter.resolveDriver(baseState(startPosition = LatLng(2.0, 2.0))),
        )
        assertEquals(
            polylineStart,
            RideMapRecenter.resolveDriver(baseState(polylinePoints = listOf(polylineStart, polylineEnd))),
        )
        assertNull(RideMapRecenter.resolveDriver(baseState(polylinePoints = emptyList())))
    }

    @Test
    fun resolvePickup_prefersLastPickupLatLng() {
        val state = baseState(lastPickupLatLng = pickup, destPosition = LatLng(0.0, 0.0))
        assertEquals(pickup, RideMapRecenter.resolvePickup(state))
    }

    @Test
    fun resolvePickup_fallsBackToDestMarkerAndPolylineEnd() {
        assertEquals(
            LatLng(3.0, 3.0),
            RideMapRecenter.resolvePickup(baseState(destPosition = LatLng(3.0, 3.0))),
        )
        assertEquals(
            polylineEnd,
            RideMapRecenter.resolvePickup(baseState(polylinePoints = listOf(polylineStart, polylineEnd))),
        )
    }

    @Test
    fun resolveDestination_prefersDestMarkerThenDropoffThenPolylineEnd() {
        assertEquals(
            dropoff,
            RideMapRecenter.resolveDestination(baseState(destPosition = dropoff)),
        )
        assertEquals(
            dropoff,
            RideMapRecenter.resolveDestination(baseState(lastDropoffLatLng = dropoff)),
        )
        assertEquals(
            polylineEnd,
            RideMapRecenter.resolveDestination(
                baseState(polylinePoints = listOf(polylineStart, polylineEnd)),
            ),
        )
    }

    @Test
    fun selectBoundsCameraMode_usesFourArgWhenDimensionsKnown() {
        assertEquals(
            RideMapRecenter.BoundsCameraMode.FourArg,
            RideMapRecenter.selectBoundsCameraMode(1080, 1920),
        )
    }

    @Test
    fun selectBoundsCameraMode_usesTwoArgWhenDimensionsZero() {
        assertEquals(
            RideMapRecenter.BoundsCameraMode.TwoArg,
            RideMapRecenter.selectBoundsCameraMode(0, 0),
        )
    }

    @Test
    fun canFitFullPolyline_requiresAtLeastTwoPoints() {
        assertFalse(RideMapRecenter.canFitFullPolyline(baseState(polylinePoints = listOf(polylineStart))))
        assertTrue(
            RideMapRecenter.canFitFullPolyline(
                baseState(polylinePoints = listOf(polylineStart, polylineEnd)),
            ),
        )
    }
}
