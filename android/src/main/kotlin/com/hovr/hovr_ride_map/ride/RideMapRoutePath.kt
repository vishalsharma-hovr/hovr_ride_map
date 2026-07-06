package com.hovr.hovr_ride_map.ride

import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.SphericalUtil

/** Route geometry helpers for in-trip driver-anchored polylines (parity with iOS). */
internal object RideMapRoutePath {
    private const val DUPLICATE_THRESHOLD_METERS = 10.0
    private const val NEAR_START_THRESHOLD_METERS = 25.0

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

    fun trimmedPath(path: List<LatLng>, driver: LatLng): List<LatLng>? {
        if (path.size < 2) return null
        val startIndex = closestIndex(path, driver)
        val result = mutableListOf<LatLng>()
        result.add(driver)
        for (index in startIndex until path.size) {
            val coordinate = path[index]
            if (result.size == 1 &&
                SphericalUtil.computeDistanceBetween(driver, coordinate) < DUPLICATE_THRESHOLD_METERS
            ) {
                continue
            }
            result.add(coordinate)
        }
        return result.takeIf { it.size > 1 }
    }

    /** Uses the stream leg as-is when the driver is near the path start; otherwise trims once. */
    fun routePathForDisplay(path: List<LatLng>, driver: LatLng): List<LatLng>? {
        if (path.size < 2) return null
        val pathStart = path.first()
        return if (SphericalUtil.computeDistanceBetween(driver, pathStart) < NEAR_START_THRESHOLD_METERS) {
            path
        } else {
            trimmedPath(path, driver)
        }
    }
}
