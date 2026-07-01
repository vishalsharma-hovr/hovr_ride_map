package com.hovr.hovr_ride_map.ride

import android.util.Log
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.PolyUtil
import com.google.maps.android.SphericalUtil

/** Polyline decode helpers for [RideMapPlatformView]. */
internal object RideMapPolylineDecoder {
    private const val TAG = "RideMapPolylineDecoder"

    fun sanitizeEncoded(input: String): String {
        var s = input.trim()
        if (s.contains("\\\\")) s = s.replace("\\\\", "\\")
        if (s.length > 1 && ((s.first() == '"' && s.last() == '"') || (s.first() == '\'' && s.last() == '\''))) {
            s = s.substring(1, s.length - 1)
        }
        return s
    }

    fun decodePolyline(encoded: String, precision: Int): List<LatLng> {
        val factor = Math.pow(10.0, precision.toDouble())
        var index = 0
        val len = encoded.length
        var lat = 0
        var lng = 0
        val path = ArrayList<LatLng>()

        try {
            while (index < len) {
                var result = 0
                var shift = 0
                var b: Int
                do {
                    if (index >= len) return path
                    b = encoded[index++].code - 63
                    result = result or ((b and 0x1f) shl shift)
                    shift += 5
                } while (b >= 0x20)
                val dlat = if ((result and 1) != 0) (result shr 1).inv() else (result shr 1)
                lat += dlat

                result = 0
                shift = 0
                do {
                    if (index >= len) return path
                    b = encoded[index++].code - 63
                    result = result or ((b and 0x1f) shl shift)
                    shift += 5
                } while (b >= 0x20)
                val dlng = if ((result and 1) != 0) (result shr 1).inv() else (result shr 1)
                lng += dlng

                path.add(LatLng(lat / factor, lng / factor))
            }
        } catch (e: Exception) {
            Log.e(TAG, "decodePolyline error: ${e.message}")
            return path
        }
        return path
    }

    fun isPlausible(points: List<LatLng>): Boolean {
        if (points.size < 2) return false
        var prev = points.first()
        var bad = 0
        for (i in 1 until minOf(points.size, 10)) {
            val cur = points[i]
            val d = SphericalUtil.computeDistanceBetween(prev, cur)
            if (d > 5_000) bad++
            prev = cur
        }
        return bad <= 1
    }

    fun safeDecodeAny(encodedRaw: String): List<LatLng> {
        val encoded = sanitizeEncoded(encodedRaw)
        if (encoded.isEmpty()) return emptyList()

        val custom5 = decodePolyline(encoded, 5)
        if (custom5.isNotEmpty()) return custom5

        val p5 = try {
            PolyUtil.decode(encoded)
        } catch (e: Throwable) {
            emptyList()
        }

        if (p5.isNotEmpty() && isPlausible(p5)) return p5

        val custom6 = decodePolyline(encoded, 6)
        if (custom6.isNotEmpty()) return custom6

        return emptyList()
    }
}
