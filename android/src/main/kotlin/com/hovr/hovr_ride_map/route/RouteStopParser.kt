package com.hovr.hovr_ride_map.route

import com.hovr.hovr_ride_map.model.StopLocation

/** Parses Flutter creation-params `stops` into [StopLocation] values. */
internal object RouteStopParser {
    fun parse(rawStops: Any?): List<StopLocation> {
        val list = rawStops as? List<*> ?: return emptyList()
        return list.mapNotNull { item ->
            val stopMap = item as? Map<*, *> ?: return@mapNotNull null
            val latitude = (stopMap["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val longitude = (stopMap["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            if (latitude == 0.0 && longitude == 0.0) return@mapNotNull null
            val address = stopMap["address"] as? String ?: ""
            StopLocation(latitude, longitude, address)
        }
    }
}
