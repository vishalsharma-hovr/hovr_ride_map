package com.hovr.hovr_ride_map.shared

import android.location.Location
import android.os.Handler
import android.os.Looper
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.Dash
import com.google.android.gms.maps.model.Gap
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.PatternItem
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

data class ComputeRouteResponse(val routes: List<Routes>? = null)
data class Routes(val polyline: Poly? = null, val duration: String? = null)
data class Poly(val encodedPolyline: String? = null)

data class DriverLocationModel(val latitude: Double, val longitude: Double)

val DASHED_PATTERN: List<PatternItem> = listOf(
    Dash(20f), Gap(20f)
)

fun getDynamicPadding(distanceMeters: Float): Int {
    return when {
        distanceMeters < 2000 -> 150
        distanceMeters < 5000 -> 120
        distanceMeters < 10000 -> 100
        distanceMeters < 20000 -> 80
        distanceMeters < 50000 -> 60
        else -> 40
    }
}

fun calculateDistanceInMeters(start: LatLng, end: LatLng): Float {
    val result = FloatArray(1)
    Location.distanceBetween(
        start.latitude, start.longitude, end.latitude, end.longitude, result
    )
    return result[0]
}

fun calculateBearing(from: LatLng, to: LatLng): Float {
    val lat1 = Math.toRadians(from.latitude)
    val lon1 = Math.toRadians(from.longitude)
    val lat2 = Math.toRadians(to.latitude)
    val lon2 = Math.toRadians(to.longitude)

    val deltaLon = lon2 - lon1
    val y = sin(deltaLon) * cos(lat2)
    val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
    val initialBearing = atan2(y, x)

    val bearing = (Math.toDegrees(initialBearing) + 360) % 360
    return bearing.toFloat()
}

fun updateCameraPosition(
    map: GoogleMap, origin: LatLng, destination: LatLng, padding: Int, bounds: LatLngBounds
) {
    val bearing = calculateBearing(origin, destination)

    Handler(Looper.getMainLooper()).postDelayed(
        {
            map.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, padding))

            Handler(Looper.getMainLooper()).postDelayed(
                {
                    val center = LatLng(
                        (origin.latitude + destination.latitude) / 2,
                        (origin.longitude + destination.longitude) / 2
                    )

                    val cameraPosition =
                        CameraPosition.Builder().target(center).zoom(map.cameraPosition.zoom).bearing(bearing).tilt(45f)
                            .build()

                    map.animateCamera(
                        CameraUpdateFactory.newCameraPosition(
                            cameraPosition
                        )
                    )
                }, 300
            )
        }, 200
    )
}
