package com.hovr.hovr_ride_map.ride

import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.SphericalUtil
import kotlin.math.min

/**
 * Route geometry helpers for in-trip driver-anchored polylines (parity with iOS).
 *
 * Never invent long GPS→vertex chords — those render as straight lines across
 * the map even when the encoded route itself is fine.
 */
internal object RideMapRoutePath {
    private const val DUPLICATE_THRESHOLD_METERS = 10.0
    private const val NEAR_START_THRESHOLD_METERS = 80.0
    /** Above this, keep the stream path as-is (no park-cutting diagonal). */
    private const val MAX_SNAP_DISTANCE_METERS = 120.0

    fun closestIndex(path: List<LatLng>, coordinate: LatLng): Int {
        if (path.isEmpty()) return 0
        var bestIndex = 0
        var bestDistance = Double.MAX_VALUE
        path.forEachIndexed { index, point ->
            val distance = SphericalUtil.computeDistanceBetween(coordinate, point)
            if (distance < bestDistance) {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    /**
     * Projects [driver] onto the nearest path edge.
     * Returns (edgeStartIndex, projectedPoint, distanceMeters).
     */
    fun closestPointOnPath(path: List<LatLng>, driver: LatLng): Triple<Int, LatLng, Double>? {
        if (path.size < 2) return null
        var bestEdge = 0
        var bestPoint = path.first()
        var bestDistance = Double.MAX_VALUE
        for (i in 0 until path.lastIndex) {
            val projected = projectOntoSegment(driver, path[i], path[i + 1])
            val distance = SphericalUtil.computeDistanceBetween(driver, projected)
            if (distance < bestDistance) {
                bestDistance = distance
                bestEdge = i
                bestPoint = projected
            }
        }
        return Triple(bestEdge, bestPoint, bestDistance)
    }

    fun trimmedPath(path: List<LatLng>, driver: LatLng): List<LatLng>? {
        if (path.size < 2) return null
        val snap = closestPointOnPath(path, driver) ?: return null
        val (edgeStart, projected, snapDistance) = snap
        if (snapDistance > MAX_SNAP_DISTANCE_METERS) {
            return path
        }

        val result = mutableListOf<LatLng>()
        result.add(projected)
        val continueFrom = min(edgeStart + 1, path.lastIndex)
        for (index in continueFrom until path.size) {
            val coordinate = path[index]
            if (result.size == 1 &&
                SphericalUtil.computeDistanceBetween(projected, coordinate) < DUPLICATE_THRESHOLD_METERS
            ) {
                continue
            }
            result.add(coordinate)
        }
        return result.takeIf { it.size > 1 }
    }

    fun routePathForDisplay(path: List<LatLng>, driver: LatLng): List<LatLng>? {
        if (path.size < 2) return null
        val pathStart = path.first()
        return if (SphericalUtil.computeDistanceBetween(driver, pathStart) < NEAR_START_THRESHOLD_METERS) {
            path
        } else {
            trimmedPath(path, driver)
        }
    }

    private fun projectOntoSegment(point: LatLng, a: LatLng, b: LatLng): LatLng {
        val segmentLength = SphericalUtil.computeDistanceBetween(a, b)
        if (segmentLength < 1.0) return a
        val headingAb = SphericalUtil.computeHeading(a, b)
        val headingAp = SphericalUtil.computeHeading(a, point)
        val distanceAp = SphericalUtil.computeDistanceBetween(a, point)
        val angleRad = Math.toRadians(headingAp - headingAb)
        val along = distanceAp * Math.cos(angleRad)
        val fraction = (along / segmentLength).coerceIn(0.0, 1.0)
        return SphericalUtil.interpolate(a, b, fraction)
    }
}
