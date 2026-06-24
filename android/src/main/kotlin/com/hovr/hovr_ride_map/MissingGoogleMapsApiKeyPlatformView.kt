package com.hovr.hovr_ride_map

import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.TextView
import com.hovr.hovr_ride_map.utils.MapViewUtils
import io.flutter.plugin.platform.PlatformView

/** Shown when the host app has not configured a Google Maps API key. */
internal class MissingGoogleMapsApiKeyPlatformView(context: Context) : PlatformView {
    private val container = FrameLayout(context).apply {
        setBackgroundColor(Color.parseColor("#F2F2F7"))
        addView(
            TextView(context).apply {
                gravity = Gravity.CENTER
                text =
                    "Google Maps API key missing.\n" +
                    "Add com.google.android.geo.API_KEY to AndroidManifest.xml."
                setTextColor(Color.parseColor("#3C3C43"))
                textSize = 15f
            },
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )
    }

    init {
        Log.w(TAG, "Skipping map view — Google Maps API key is not configured.")
    }

    override fun getView() = container

    override fun dispose() = Unit

    companion object {
        private const val TAG = "hovr_ride_map"

        fun createOrMap(
            context: Context,
            configured: () -> PlatformView,
        ): PlatformView {
            if (!MapViewUtils.isGoogleMapsConfigured(context)) {
                return MissingGoogleMapsApiKeyPlatformView(context)
            }
            return configured()
        }
    }
}
