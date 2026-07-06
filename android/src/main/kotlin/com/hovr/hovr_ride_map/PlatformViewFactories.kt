package com.hovr.hovr_ride_map

import android.content.Context
import com.hovr.hovr_ride_map.home.HomeMapPlatformView
import com.hovr.hovr_ride_map.ride.RideMapPlatformView
import com.hovr.hovr_ride_map.route.RoutePreviewPlatformView
import com.google.android.gms.maps.model.LatLng
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class HomeMapPlatformViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val argsMap = args as? Map<*, *> ?: emptyMap<String, Any?>()
        return MissingGoogleMapsApiKeyPlatformView.createOrMap(context) {
            HomeMapPlatformView(context, messenger, argsMap)
        }
    }
}

class RideMapPlatformViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val mode = (args as? Map<*, *>)?.get("mode") as? String
        return MissingGoogleMapsApiKeyPlatformView.createOrMap(context) {
            RideMapPlatformView(context, messenger, mapMode = mode)
        }
    }
}

class RoutePreviewPlatformViewFactory(
    private val messenger: BinaryMessenger,
    private val origin: LatLng,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val argsMap = args as? Map<*, *> ?: emptyMap<String, Any?>()
        return MissingGoogleMapsApiKeyPlatformView.createOrMap(context) {
            RoutePreviewPlatformView(context, messenger, argsMap, origin)
        }
    }
}
