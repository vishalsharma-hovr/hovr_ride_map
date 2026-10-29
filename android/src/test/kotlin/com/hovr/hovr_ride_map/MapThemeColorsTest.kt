package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.shared.MapThemeColors
import org.junit.Assert.assertEquals
import org.junit.Test

class MapThemeColorsTest {

    @Test
    fun fromArgs_withoutColors_keepsHovrGreens() {
        assertEquals(MapThemeColors(), MapThemeColors.fromArgs(null))
        assertEquals(MapThemeColors(), MapThemeColors.fromArgs("not a map"))
        assertEquals(0xFF4AAB24.toInt(), MapThemeColors().accent)
    }

    @Test
    fun fromArgs_usesTheHostAppThemeColors() {
        // Dart sends unsigned ARGB, which can arrive as Long.
        val colors = MapThemeColors.fromArgs(
            mapOf("accent" to 0xFFFF7518L, "onSurface" to 0xFFF2F3F1.toInt()),
        )

        assertEquals(0xFFFF7518.toInt(), colors.accent)
        assertEquals(0xFFF2F3F1.toInt(), colors.onSurface)
        assertEquals(MapThemeColors().surface, colors.surface)
    }

    @Test
    fun fromArgs_ignoresValuesThatAreNotColors() {
        val colors = MapThemeColors.fromArgs(mapOf("accent" to "orange"))

        assertEquals(MapThemeColors().accent, colors.accent)
    }
}
