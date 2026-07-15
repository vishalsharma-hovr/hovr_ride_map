package com.hovr.hovr_ride_map

import com.google.android.gms.maps.model.LatLng
import io.flutter.embedding.engine.plugins.FlutterPlugin

/** Registers HOVR ride map platform views and the shared ride-view channel hub. */
class HovrRideMapPlugin : FlutterPlugin {
    private var origin: LatLng = LatLng(0.0, 0.0)

    fun setOrigin(lat: Double, lng: Double) {
        origin = LatLng(lat, lng)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        RideViewChannelHub.install(messenger)

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
    }
}
