package com.hovr.hovr_ride_map.ride

import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.PolyUtil

/**
 * Polyline decode helpers for [RideMapPlatformView].
 *
 * Mirrors iOS [cleanedEncodedPolyline] + [GMSPath.fromEncodedPath] in
 * `MapGeometryHelpers.swift` — sanitize, then Google precision-5 decode only.
 */
internal object RideMapPolylineDecoder {
    /**
     * Same cleaning as iOS `cleanedEncodedPolyline`:
     * trim whitespace, strip quotes, unescape double backslashes.
     */
    fun sanitizeEncoded(input: String): String =
        input
            .trim()
            .replace("\"", "")
            .replace("'", "")
            .replace("\\\\", "\\")

    /**
     * Decode like iOS `gmsPath(fromEncodedPolyline:)` → `GMSPath(fromEncodedPath:)`.
     * Uses Maps SDK [PolyUtil.decode] (precision 5), not a custom/precision-6 fallback.
     */
    fun safeDecodeAny(encodedRaw: String): List<LatLng> {
        val encoded = sanitizeEncoded(encodedRaw)
        if (encoded.isEmpty()) return emptyList()
        return try {
            PolyUtil.decode(encoded)
        } catch (_: Throwable) {
            emptyList()
        }
    }

    /** Skip redraw when the encoded polyline is unchanged (matches iOS dedup). */
    fun shouldSkipPolylineRedraw(newPolyline: String, lastDrawn: String?): Boolean {
        return lastDrawn != null && newPolyline == lastDrawn
    }
}
