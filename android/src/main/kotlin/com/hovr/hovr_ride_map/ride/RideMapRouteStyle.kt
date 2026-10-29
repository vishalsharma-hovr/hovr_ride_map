package com.hovr.hovr_ride_map.ride

import android.content.Context
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.JointType
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.Polyline
import com.google.android.gms.maps.model.PolylineOptions
import com.google.android.gms.maps.model.RoundCap
import com.hovr.hovr_ride_map.shared.MapThemeColors

/**
 * HOVR brand green route stroke.
 *
 * Width is a fixed screen size (dp → pixels). Google Maps does **not** scale
 * polyline width with camera zoom — one stroke value is used at every zoom.
 */
internal object RideMapRouteStyle {
    /** The app theme's accent (HOVR green by default) — matches iOS in-trip route. */
    val strokeColor: Int
        get() = MapThemeColors.current.accent

    /** Core stroke width in dp — mirrors iOS [RideMapRouteStyle.strokeWidth] (4–5pt). */
    const val strokeWidthDp: Float = 5f

    const val strokeZIndex: Float = 100f

    fun addRoutePolyline(
        map: GoogleMap,
        points: List<LatLng>,
        context: Context,
    ): List<Polyline> {
        val density = context.resources.displayMetrics.density
        val strokeWidthPx = strokeWidthDp * density
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
        return listOf(stroke)
    }
}
