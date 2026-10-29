package com.hovr.hovr_ride_map.route

import android.content.Context
import android.graphics.Bitmap
import android.text.TextUtils
import android.view.LayoutInflater
import android.widget.TextView
import com.hovr.hovr_ride_map.R
import com.hovr.hovr_ride_map.shared.MapThemeTint
import com.hovr.hovr_ride_map.utils.MapViewUtils.createBitmapFromView

internal enum class RouteTaggedMarkerKind {
    DESTINATION,
    STOP,
}

internal data class RouteTaggedMarkerTag(
    val kind: RouteTaggedMarkerKind,
    val tagLabel: String,
    val address: String,
    val stopNumber: Int = 0,
    var expanded: Boolean = false,
)

/** Builds destination/stop pill markers for the route preview map. */
internal object RouteTaggedMarkerBitmap {
    private const val COLLAPSED_ADDRESS_WIDTH_DP = 100f
    private const val EXPANDED_HORIZONTAL_INSET_DP = 140f

    fun bitmapFor(context: Context, tag: RouteTaggedMarkerTag): Bitmap {
        val markerView = LayoutInflater.from(context).inflate(R.layout.route_tag_marker, null)
        bind(markerView, context, tag)
        return createBitmapFromView(markerView)
    }

    fun bind(
        markerView: android.view.View,
        context: Context,
        tag: RouteTaggedMarkerTag,
    ) {
        val density = context.resources.displayMetrics.density
        val addressView = markerView.findViewById<TextView>(R.id.addressTextView)
        val tagView = markerView.findViewById<TextView>(R.id.tagLabelTextView)

        MapThemeTint.applyToTagMarker(markerView)
        tagView.text = tag.tagLabel
        addressView.text = tag.address.ifBlank { tag.tagLabel }
        addressView.maxLines = if (tag.expanded) 2 else 1
        addressView.ellipsize = TextUtils.TruncateAt.END

        val addressWidthPx = if (tag.expanded) {
            val screenWidthPx = context.resources.displayMetrics.widthPixels
            (screenWidthPx - EXPANDED_HORIZONTAL_INSET_DP * density)
                .toInt()
                .coerceAtLeast((COLLAPSED_ADDRESS_WIDTH_DP * density).toInt())
        } else {
            (COLLAPSED_ADDRESS_WIDTH_DP * density).toInt()
        }
        addressView.layoutParams = addressView.layoutParams.apply {
            width = addressWidthPx
        }
    }
}
