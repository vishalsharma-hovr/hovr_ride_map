package com.hovr.hovr_ride_map

import com.google.android.gms.maps.model.LatLng
import com.hovr.hovr_ride_map.shared.MapStylePolicy
import com.hovr.hovr_ride_map.shared.FestiveMarkers
import com.hovr.hovr_ride_map.shared.HovrCarIcon
import com.hovr.hovr_ride_map.shared.MapThemeColors
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Registers HOVR ride map platform views and the shared ride-view channel hub. */
class HovrRideMapPlugin : FlutterPlugin {
    private var origin: LatLng = LatLng(0.0, 0.0)
    private var styleChannel: MethodChannel? = null

    fun setOrigin(lat: Double, lng: Double) {
        origin = LatLng(lat, lng)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        RideViewChannelHub.install(messenger)
        styleChannel = MethodChannel(messenger, "hovr-ride-map/style").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "set-map-style" ->
                        MapStylePolicy.update((call.arguments as? Map<*, *>)?.get("json") as? String)
                    // Applies to routes and markers drawn from now on.
                    "set-map-colors" -> MapThemeColors.update(call.arguments)
                    // Festive car for every map; null restores the HOVR car.
                    "set-car-icon" -> HovrCarIcon.setFestiveCar((call.arguments as? Map<*, *>)?.get("png") as? ByteArray)
                    // Decorative festive items on the home map; an empty list clears them.
                    "set-festive-markers" -> FestiveMarkers.update(call.arguments)
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                result.success(null)
            }
        }

        val registry = binding.platformViewRegistry
        registry.registerViewFactory("home-view-google-map", HomeMapPlatformViewFactory(messenger))
        registry.registerViewFactory("hovr-ride-map-view", RideMapPlatformViewFactory(messenger))
        // Legacy aliases kept during migration.
        registry.registerViewFactory("meet-at-pickup-spot-view", RideMapPlatformViewFactory(messenger))
        registry.registerViewFactory("google-map-view", RideMapPlatformViewFactory(messenger))
        registry.registerViewFactory(
            "routes-on-map-view",
            RoutePreviewPlatformViewFactory(messenger, origin),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Clear hub so the next engine attach rebinds ride-view-channel to the new messenger.
        // Without this, Activity/engine recreate (FGS keeps process) leaves the hub on a dead
        // BinaryMessenger and Dart trip-stream map updates never reach native.
        RideViewChannelHub.uninstall()
        styleChannel?.setMethodCallHandler(null)
        styleChannel = null
    }
}
