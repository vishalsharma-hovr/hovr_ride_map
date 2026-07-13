package com.hovr.hovr_ride_map

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Single permanent handler for [ride-view-channel].
 *
 * Mirrors iOS `PolylineController` / global bridge targeting: in-trip route and
 * driver updates always go to [RideMapPlatformView], never to HomeMap/RoutePreview
 * handlers that may sit on top of the generic stack and return `notImplemented`.
 *
 * When no ride map is registered yet, [driver-location-update] and
 * [polylines-channel] are buffered and replayed on the next [pushRideMap].
 */
object RideViewChannelHub {
    private const val TAG = "RideViewChannelHub"

    private val handlers = ArrayDeque<MethodChannel.MethodCallHandler>()
    private var rideMapHandler: MethodChannel.MethodCallHandler? = null
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

    /** Methods that must reach the in-trip ride map (iOS global polyline/driver path). */
    private val rideMapOwnedMethods = setOf(
        "polylines-channel",
        "driver-location-update",
        "clear-route",
        "clear-driver-location",
        "trip-stage",
        "pickup-location",
        "user-location",
        "drop-off-location",
        "trip-stops",
        "clear-pickup-user-markers",
        "eta-channel",
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

    /** Generic stack (home / route-preview) for recenter and similar. */
    fun push(handler: MethodChannel.MethodCallHandler) {
        synchronized(lock) {
            handlers.addLast(handler)
        }
    }

    fun pop(handler: MethodChannel.MethodCallHandler) {
        synchronized(lock) { handlers.remove(handler) }
    }

    /** In-trip [RideMapPlatformView] — owns polylines and driver location. */
    fun pushRideMap(handler: MethodChannel.MethodCallHandler) {
        synchronized(lock) {
            rideMapHandler = handler
            replayPendingTo(handler)
        }
    }

    fun popRideMap(handler: MethodChannel.MethodCallHandler) {
        synchronized(lock) {
            if (rideMapHandler === handler) {
                rideMapHandler = null
            }
        }
    }

    private fun dispatchLocked(call: MethodCall, result: MethodChannel.Result) {
        applyClearPending(call.method)

        val handler = resolveHandler(call.method)
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

    private fun resolveHandler(method: String): MethodChannel.MethodCallHandler? {
        if (method in rideMapOwnedMethods) {
            return rideMapHandler ?: handlers.lastOrNull()
        }
        return handlers.lastOrNull() ?: rideMapHandler
    }

    /** Visible for unit tests. */
    internal fun targetHandlerForTest(method: String): MethodChannel.MethodCallHandler? =
        synchronized(lock) { resolveHandler(method) }

    /** Visible for unit tests — clears stack state between tests. */
    internal fun resetForTest() {
        synchronized(lock) {
            handlers.clear()
            rideMapHandler = null
            pendingDriverLocation = null
            pendingPolyline = null
        }
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
                        force = ChannelArgParsers.boolFrom(arg, "force"),
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
