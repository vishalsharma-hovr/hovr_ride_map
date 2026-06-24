package com.hovr.hovr_ride_map

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Single permanent handler for [ride-view-channel].
 *
 * Platform map views push/pop their own delegates so disposing one view never
 * leaves the channel without a handler.
 */
object RideViewChannelHub {
    private val handlers = ArrayDeque<MethodChannel.MethodCallHandler>()
    private val lock = Any()
    private var installed = false

    private val noopMethods = setOf(
        "recenter-map",
        "driver-location-update",
        "polylines-channel",
        "clear-route",
        "eta-channel",
        "trip-stage",
        "pickup-location",
        "user-location",
        "drop-off-location",
    )

    fun install(messenger: BinaryMessenger) {
        synchronized(lock) {
            if (installed) return
            MethodChannel(messenger, RideMapChannels.rideView).setMethodCallHandler { call, result ->
                val handler = handlers.lastOrNull()
                if (handler != null) {
                    handler.onMethodCall(call, result)
                } else if (call.method in noopMethods) {
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
            installed = true
        }
    }

    fun push(handler: MethodChannel.MethodCallHandler) {
        synchronized(lock) { handlers.addLast(handler) }
    }

    fun pop(handler: MethodChannel.MethodCallHandler) {
        synchronized(lock) { handlers.remove(handler) }
    }
}

object RideMapChannels {
    const val rideView = "ride-view-channel"
    const val showDrivers = "show-drivers-location-on-map"
    const val routesOnMap = "routes-on-map-view"
    const val meetAtPickup = "meet-at-pickup-spot-view"
    const val globalChannel = "com.hovr/global_channel"
}
