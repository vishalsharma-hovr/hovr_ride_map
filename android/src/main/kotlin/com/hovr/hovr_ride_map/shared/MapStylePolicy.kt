package com.hovr.hovr_ride_map.shared

import android.content.Context
import android.util.Log
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.MapStyleOptions
import java.util.WeakHashMap

private const val TAG = "MapStylePolicy"

/**
 * Host app's map style (light/dark/festive) for every ride map. With no host
 * style, each map keeps its own default ([attach]'s `defaultStyleRes`, or
 * Google's look when null). Call on the main thread.
 */
object MapStylePolicy {
    private var hostJson: String? = null

    // Weak keys: a disposed map view drops out without an explicit detach.
    private val maps = WeakHashMap<GoogleMap, Pair<Context, Int?>>()

    /** Styles [map] now and whenever the host app's style changes. */
    fun attach(map: GoogleMap, context: Context, defaultStyleRes: Int?) {
        val entry = context.applicationContext to defaultStyleRes
        maps[map] = entry
        style(map, entry)
    }

    /** Restyles every attached map; null restores each map's default look. */
    fun update(json: String?) {
        hostJson = json
        maps.forEach { (map, entry) -> style(map, entry) }
    }

    private fun style(map: GoogleMap, entry: Pair<Context, Int?>) {
        val (context, defaultStyleRes) = entry
        try {
            val options = hostJson?.let { MapStyleOptions(it) }
                ?: defaultStyleRes?.let { MapStyleOptions.loadRawResourceStyle(context, it) }
            if (!map.setMapStyle(options)) Log.w(TAG, "Map style was rejected by Google Maps")
        } catch (e: Exception) {
            Log.e(TAG, "Map style failed: ${e.message}")
        }
    }
}
