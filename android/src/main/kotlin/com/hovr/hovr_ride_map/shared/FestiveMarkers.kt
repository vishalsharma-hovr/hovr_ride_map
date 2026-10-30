package com.hovr.hovr_ride_map.shared

import android.graphics.BitmapFactory
import android.util.Log
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions
import java.util.WeakHashMap

private const val TAG = "FestiveMarkers"

/**
 * Decorative festive items on the home map(s), sent by the host app. Drawn
 * centred, under every other marker and slightly see-through; taps are already
 * consumed by [MapChromePolicy], so they never act like real places. Call on
 * the main thread.
 */
object FestiveMarkers {
    /** Most items drawn at once, whatever the app sends. */
    const val MAX_MARKERS = 12

    /** One item: where, and its badge image. */
    class Spec(val lat: Double, val lng: Double, val png: ByteArray)

    private var specs: List<Spec> = emptyList()

    // Weak keys: a disposed map view drops out without an explicit detach.
    private val shown = WeakHashMap<GoogleMap, MutableList<Marker>>()

    /** Draws the current items on [map] now and on every later [update]. */
    fun attach(map: GoogleMap) {
        shown[map] = mutableListOf()
        draw(map)
    }

    /** Replaces the items on every attached map; an empty list clears them. */
    fun update(arguments: Any?) {
        specs = parse(arguments)
        shown.keys.toList().forEach { draw(it) }
    }

    /** `{"markers": [{"lat", "lng", "png"}]}` → valid items, at most [MAX_MARKERS]. */
    fun parse(arguments: Any?): List<Spec> {
        val raw = (arguments as? Map<*, *>)?.get("markers") as? List<*> ?: return emptyList()
        return raw.mapNotNull { entry ->
            val m = entry as? Map<*, *> ?: return@mapNotNull null
            val lat = (m["lat"] as? Number)?.toDouble() ?: return@mapNotNull null
            val lng = (m["lng"] as? Number)?.toDouble() ?: return@mapNotNull null
            val png = (m["png"] as? ByteArray)?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
            Spec(lat, lng, png)
        }.take(MAX_MARKERS)
    }

    private fun draw(map: GoogleMap) {
        val markers = shown[map] ?: return
        markers.forEach { it.remove() }
        markers.clear()
        for (spec in specs) {
            val bitmap = BitmapFactory.decodeByteArray(spec.png, 0, spec.png.size)
            if (bitmap == null) {
                Log.w(TAG, "Skipped a festive marker whose image could not be decoded")
                continue
            }
            val marker = map.addMarker(
                MarkerOptions()
                    .position(LatLng(spec.lat, spec.lng))
                    .icon(BitmapDescriptorFactory.fromBitmap(bitmap))
                    .anchor(0.5f, 0.5f)
                    .alpha(0.9f)
                    .zIndex(-1f),
            )
            if (marker != null) markers.add(marker)
        }
    }
}
