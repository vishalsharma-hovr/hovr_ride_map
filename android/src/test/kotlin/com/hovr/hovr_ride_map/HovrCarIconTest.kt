package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.shared.HovrCarIcon
import org.junit.Assert.assertEquals
import org.junit.Test

class HovrCarIconTest {
    @Test
    fun defaultSize_matchesIosTripCarIcon() {
        assertEquals(28, HovrCarIcon.DEFAULT_SIZE_DP)
    }

    @Test
    fun multiply_turnsTheWhiteBodyIntoTheThemeColor() {
        assertEquals(0xFFFF7518.toInt(), HovrCarIcon.multiply(0xFFFFFFFF.toInt(), 0xFFFF7518.toInt()))
    }

    @Test
    fun multiply_keepsDarkWindowsDark() {
        assertEquals(0xFF000000.toInt(), HovrCarIcon.multiply(0xFF000000.toInt(), 0xFFFF7518.toInt()))
    }

    @Test
    fun multiply_shadesGreyAndKeepsThePixelAlpha() {
        // 50% grey at 50% alpha: each channel halves, alpha stays the icon's.
        assertEquals(0x80803A0C.toInt(), HovrCarIcon.multiply(0x80808080.toInt(), 0xFFFF7518.toInt()))
    }

    @Test
    fun festiveSize_keepsATallCarTallAtTheMarkerLength() {
        // 120×240 festive artwork at a 28 px marker: 14 wide, 28 long.
        assertEquals(14 to 28, HovrCarIcon.festiveSizePx(28, 120, 240))
    }

    @Test
    fun festiveSize_keepsASquareImageSquare() {
        assertEquals(28 to 28, HovrCarIcon.festiveSizePx(28, 100, 100))
    }

    @Test
    fun festiveSize_neverReturnsAnEmptyBitmap() {
        assertEquals(1 to 28, HovrCarIcon.festiveSizePx(28, 1, 1000))
        assertEquals(28 to 28, HovrCarIcon.festiveSizePx(28, 10, 0))
    }
}

