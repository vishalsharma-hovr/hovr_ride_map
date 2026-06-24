package com.hovr.hovr_ride_map.home

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.core.content.ContextCompat
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import kotlin.math.*
import androidx.core.graphics.createBitmap

object BearingCalculator {

    // Consider < 1 m as "stationary" jitter
    private const val STATIONARY_EPS_METERS = 1.0

    // Public: simple two-point initial course (0..360)
    fun calculate(start: LatLng, end: LatLng): Float {
        val lat1 = Math.toRadians(start.latitude)
        val lon1 = Math.toRadians(start.longitude)
        val lat2 = Math.toRadians(end.latitude)
        val lon2 = Math.toRadians(end.longitude)

        val dLon = lon2 - lon1
        val y = sin(dLon) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        val br = Math.toDegrees(atan2(y, x))
        return normalize(br.toFloat())
    }

    /**
     * Road-aware bearing with stationary handling and optional asset offset.
     *
     * - If previous→current moved ≥ 1 m, use that course.
     * - Else if next exists, use current→next as look-ahead.
     * - Else fall back to lastKnownBearing (e.g., what the marker was already showing).
     * - Finally add assetForwardOffsetDeg (e.g., -90 if the car vector points RIGHT).
     *
     * Returns a display-ready rotation in [0, 360).
     */
    fun calculateRoadBearing(
        previousPosition: LatLng?,         // where we were
        currentPosition: LatLng?,          // where we are
        nextPosition: LatLng?,             // where we are heading
        lastKnownBearing: Float? = null,   // keep heading when stationary
        assetForwardOffsetDeg: Float = 0f  // drawable's intrinsic forward offset
    ): Float {
        val base: Float? = when {
            previousPosition != null && currentPosition != null -> {
                val moved = distanceMeters(previousPosition, currentPosition)
                if (moved >= STATIONARY_EPS_METERS) {
                    calculate(previousPosition, currentPosition)
                } else if (nextPosition != null) {
                    calculate(currentPosition, nextPosition)
                } else {
                    lastKnownBearing
                }
            }

            currentPosition != null && nextPosition != null -> {
                calculate(currentPosition, nextPosition)
            }

            else -> lastKnownBearing
        }

        // If still null, choose 0 as a safe default
        val withOffset = (base ?: 90f) + assetForwardOffsetDeg
        return normalize(withOffset)
    }

    /* ────────────────────────── helpers ────────────────────────── */

    private fun normalize(deg: Float): Float {
        val v = deg % 360f
        return if (v >= 0f) v else v + 360f
    }

    // Minimal Haversine (meters)
    private fun distanceMeters(a: LatLng, b: LatLng): Double {
        val R = 6_371_000.0
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLng = Math.toRadians(b.longitude - a.longitude)
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val h = sin(dLat / 2).pow(2) + sin(dLng / 2).pow(2) * cos(lat1) * cos(lat2)
        return 2 * R * asin(sqrt(h))
    }
}

object BitmapUtils {
    fun getBitmapDescriptorFromVector(
        context: Context,
        vectorResId: Int,
        widthDp: Int,
        heightDp: Int
    ): BitmapDescriptor {
        val drawable = ContextCompat.getDrawable(context, vectorResId)!!
        val scale = context.resources.displayMetrics.density
        val widthPx = (widthDp * scale).toInt()
        val heightPx = (heightDp * scale).toInt()

        drawable.setBounds(0, 0, widthPx, heightPx)

        val bitmap = createBitmap(widthPx, heightPx)
        val canvas = Canvas(bitmap)
        drawable.draw(canvas)

        return BitmapDescriptorFactory.fromBitmap(bitmap)
    }
}