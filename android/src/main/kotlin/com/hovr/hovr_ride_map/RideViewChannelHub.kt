package com.hovr.hovr_ride_map

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Single permanent handler for [ride-view-channel].
 *
 * Platform map views push/pop their own delegates so disposing one view never
 * leaves the channel without a handler.
 *
 * When no in-trip map view has registered yet (common during release AOT
 * transitions from HomeMapView → RideMapView), [driver-location-update] and
 * [polylines-channel] payloads are buffered and replayed on the next [push].
 */
object RideViewChannelHub {
    private const val TAG = "RideViewChannelHub"

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
        "trip-stops",
        "clear-pickup-user-markers",
        "clear-driver-location",
    )

    private val bufferableMethods = setOf(
        "driver-location-update",
        "polylines-channel",
    )

    internal data class PendingDriverLocation(
        val lat: Double,
        val lng: Double,
        val bearing: Float?,
    )

    internal data class PendingPolyline(
        val polyline: String,
        val force: Boolean,
    )

    internal var pendingDriverLocation: PendingDriverLocation? = null
        private set
    internal var pendingPolyline: PendingPolyline? = null
        private set

    fun install(messenger: BinaryMessenger) {
        synchronized(lock) {
            if (installed) return
            MethodChannel(messenger, RideMapChannels.rideView).setMethodCallHandler { call, result ->
                synchronized(lock) {
                    dispatchLocked(call, result)
                }
            }
            installed = true
        }
    }

    fun push(handler: MethodChannel.MethodCallHandler) {
        synchronized(lock) {
            handlers.addLast(handler)
            replayPendingTo(handler)
        }
    }

    fun pop(handler: MethodChannel.MethodCallHandler) {
        synchronized(lock) { handlers.remove(handler) }
    }

    private fun dispatchLocked(call: MethodCall, result: MethodChannel.Result) {
        applyClearPending(call.method)

        val handler = handlers.lastOrNull()
        if (handler != null) {
            handler.onMethodCall(call, result)
            if (call.method in bufferableMethods) {
                capturePending(call)
            }
            return
        }

        if (call.method in noopMethods) {
            if (call.method in bufferableMethods) {
                capturePending(call)
                Log.d(TAG, "Buffered ${call.method} — no ride map handler registered yet")
            }
            result.success(null)
            return
        }

        result.notImplemented()
    }

    internal fun capturePending(call: MethodCall) {
        when (call.method) {
            "driver-location-update" -> {
                val arg = call.arguments as? Map<*, *> ?: return
                val (lat, lng) = ChannelArgParsers.latLngFrom(arg) ?: return
                pendingDriverLocation = PendingDriverLocation(
                    lat = lat,
                    lng = lng,
                    bearing = ChannelArgParsers.bearingFrom(arg),
                )
            }

            "polylines-channel" -> {
                val arg = call.arguments as? Map<*, *> ?: return
                val polyline = arg["polyline"] as? String
                pendingPolyline = if (polyline.isNullOrEmpty()) {
                    null
                } else {
                    PendingPolyline(
                        polyline = polyline,
                        force = arg["force"] as? Boolean ?: false,
                    )
                }
            }
        }
    }

    internal fun applyClearPending(method: String) {
        when (method) {
            "clear-route" -> {
                pendingPolyline = null
                pendingDriverLocation = null
            }

            "clear-driver-location" -> {
                pendingDriverLocation = null
            }
        }
    }

    private fun replayPendingTo(handler: MethodChannel.MethodCallHandler) {
        val noopResult = object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.w(TAG, "Replay failed: $errorCode $errorMessage")
            }

            override fun notImplemented() {}
        }

        pendingPolyline?.let { pending ->
            val args = mutableMapOf<String, Any>("polyline" to pending.polyline)
            if (pending.force) {
                args["force"] = true
            }
            Log.d(TAG, "Replaying buffered polylines-channel (len=${pending.polyline.length})")
            handler.onMethodCall(MethodCall("polylines-channel", args), noopResult)
        }

        pendingDriverLocation?.let { pending ->
            val args = mutableMapOf<String, Any>(
                "lat" to pending.lat,
                "lng" to pending.lng,
            )
            pending.bearing?.let { args["bearing"] = it }
            Log.d(TAG, "Replaying buffered driver-location-update")
            handler.onMethodCall(MethodCall("driver-location-update", args), noopResult)
        }
    }
}

object RideMapChannels {
    const val rideView = "ride-view-channel"
    const val showDrivers = "show-drivers-location-on-map"
    const val routesOnMap = "routes-on-map-view"
    const val meetAtPickup = "meet-at-pickup-spot-view"
    const val globalChannel = "com.hovr/global_channel"
}
