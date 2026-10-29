package com.hovr.hovr_ride_map.shared

import android.content.res.ColorStateList
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import com.hovr.hovr_ride_map.R

/** Paints marker drawables and inflated marker layouts in [MapThemeColors.current]. */
internal object MapThemeTint {

    /** Recolours a two-circle layer-list (outer ring, inner dot) in place. */
    fun rings(drawable: Drawable?, colors: MapThemeColors = MapThemeColors.current) {
        val layers = drawable?.mutate() as? LayerDrawable ?: return
        if (layers.numberOfLayers < 2) return
        (layers.getDrawable(0) as? GradientDrawable)?.setColor(colors.accent)
        (layers.getDrawable(1) as? GradientDrawable)?.setColor(colors.accentContainer)
    }

    /** `custom_starting_point.xml`: an ImageView showing a two-circle drawable. */
    fun applyToStartingPoint(root: View) {
        val image = root as? ImageView ?: (root as? ViewGroup)?.getChildAt(0) as? ImageView
        rings(image?.drawable)
        image?.invalidate()
    }

    /** `eta_marker.xml`: bubble, "min" texts, pointer and base dot. */
    fun applyToEtaMarker(root: View) {
        val colors = MapThemeColors.current
        fill(root.findViewById(R.id.eta_bubble), colors.accentStrong)
        root.findViewById<TextView>(R.id.eta_text)?.setTextColor(colors.onAccent)
        root.findViewById<TextView>(R.id.eta_min)?.setTextColor(colors.onAccent)
        fill(root.findViewById(R.id.eta_pointer), colors.accentStrong)
        rings(root.findViewById<View>(R.id.eta_base)?.background, colors)
    }

    /** `route_tag_marker.xml`: white address pill with a green tag. */
    fun applyToTagMarker(root: View) {
        val colors = MapThemeColors.current
        fill(root, colors.surface)
        fill(root.findViewById(R.id.route_tag_pill), colors.accentStrong)
        rings(root.findViewById<ImageView>(R.id.route_tag_dot)?.drawable, colors)
        root.findViewById<TextView>(R.id.tagLabelTextView)?.setTextColor(colors.onAccent)
        root.findViewById<TextView>(R.id.addressTextView)?.setTextColor(colors.onSurface)
        root.findViewById<ImageView>(R.id.route_tag_arrow)?.imageTintList =
            ColorStateList.valueOf(colors.onSurface)
    }

    private fun fill(view: View?, color: Int) {
        when (val background = view?.background?.mutate()) {
            is GradientDrawable -> background.setColor(color)
            is ColorDrawable -> background.color = color
        }
    }
}
