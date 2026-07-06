package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.shared.HovrCarIcon
import org.junit.Assert.assertEquals
import org.junit.Test

class HovrCarIconTest {
    @Test
    fun defaultSize_matchesIosTripCarIcon() {
        assertEquals(28, HovrCarIcon.DEFAULT_SIZE_DP)
    }
}
