package com.hovr.hovr_ride_map.ride

import android.graphics.Color
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.JointType
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.Polyline
import com.google.android.gms.maps.model.PolylineOptions
import com.google.android.gms.maps.model.RoundCap

/**
 * Uber-like route stroke using HOVR brand green: wide soft casing under a solid core.
 */
internal object RideMapRouteStyle {
    /** HOVR brand green — matches app / iOS in-trip route. */
    val strokeColor: Int = Color.parseColor("#4AAB24")

    /** Soft halo behind the core (Uber-style casing, brand-tinted). */
    val casingColor: Int = Color.argb(0x5A, 0x4A, 0xAB, 0x24)

    const val strokeWidthPx: Float = 7f
    const val casingWidthPx: Float = 14f

    const val casingZIndex: Float = 99f
    const val strokeZIndex: Float = 100f

    fun addCasingAndStroke(map: GoogleMap, points: List<LatLng>): List<Polyline> {
        val casing = map.addPolyline(
            PolylineOptions()
                .addAll(points)
                .width(casingWidthPx)
                .color(casingColor)
                .geodesic(true)
                .jointType(JointType.ROUND)
                .startCap(RoundCap())
                .endCap(RoundCap())
                .zIndex(casingZIndex),
        )
        val stroke = map.addPolyline(
            PolylineOptions()
                .addAll(points)
                .width(strokeWidthPx)
                .color(strokeColor)
                .geodesic(true)
                .jointType(JointType.ROUND)
                .startCap(RoundCap())
                .endCap(RoundCap())
                .zIndex(strokeZIndex),
        )
        return listOf(casing, stroke)
    }
}
