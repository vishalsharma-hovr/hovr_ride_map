package com.hovr.hovr_ride_map.shared

/**
 * Route and marker colours from the host app's theme (light/dark/festive),
 * as ARGB ints. Defaults are HOVR's greens, used until the app sends colours.
 */
data class MapThemeColors(
    /** Route line, marker rings and dots. */
    val accent: Int = 0xFF4AAB24.toInt(),
    /** ETA bubble and tag pill backgrounds. */
    val accentStrong: Int = 0xFF275A13.toInt(),
    /** Inner ring of the start/destination icon. */
    val accentContainer: Int = 0xFFD0EEC4.toInt(),
    /** Text and icons on [accent] / [accentStrong]. */
    val onAccent: Int = 0xFFFFFFFF.toInt(),
    /** Address tag and stop marker backgrounds. */
    val surface: Int = 0xFFFFFFFF.toInt(),
    /** Text and icons on [surface]. */
    val onSurface: Int = 0xFF1E1E1E.toInt(),
) {
    companion object {
        /** Colours for the next route or marker drawn. Read and written on the main thread. */
        var current = MapThemeColors()
            private set

        fun update(args: Any?) {
            current = fromArgs(args)
        }

        /** Reads ARGB values by token name; missing or invalid tokens keep the HOVR default. */
        fun fromArgs(args: Any?): MapThemeColors {
            val colors = args as? Map<*, *> ?: return MapThemeColors()
            val defaults = MapThemeColors()
            fun read(key: String, fallback: Int): Int = (colors[key] as? Number)?.toInt() ?: fallback
            return MapThemeColors(
                accent = read("accent", defaults.accent),
                accentStrong = read("accentStrong", defaults.accentStrong),
                accentContainer = read("accentContainer", defaults.accentContainer),
                onAccent = read("onAccent", defaults.onAccent),
                surface = read("surface", defaults.surface),
                onSurface = read("onSurface", defaults.onSurface),
            )
        }
    }
}
