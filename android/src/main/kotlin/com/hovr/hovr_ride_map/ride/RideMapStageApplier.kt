package com.hovr.hovr_ride_map.ride

internal object RideMapStageApplier {
    fun defaultZoom(stage: String?): Float = when (stage) {
        "findingDriver" -> 14f
        "meetAtPickup", "driverWaitingAtPickup", "driverReachedAtPickup" -> 16f
        "headingToDestination" -> 17f
        else -> 15f
    }

    fun prefersRouteCamera(stage: String?): Boolean = stage == "headingToDestination"
}
