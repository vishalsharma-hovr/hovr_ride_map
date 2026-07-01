package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.utils.MapViewUtils
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MapViewUtilsTest {
    @Test
    fun isValidGoogleMapsApiKey_rejectsBlankAndPlaceholders() {
        assertFalse(MapViewUtils.isValidGoogleMapsApiKey(null))
        assertFalse(MapViewUtils.isValidGoogleMapsApiKey(""))
        assertFalse(MapViewUtils.isValidGoogleMapsApiKey("   "))
        assertFalse(MapViewUtils.isValidGoogleMapsApiKey("\$(GOOGLE_MAPS_API_KEY)"))
        assertFalse(MapViewUtils.isValidGoogleMapsApiKey("YOUR_API_KEY"))
    }

    @Test
    fun isValidGoogleMapsApiKey_acceptsRealKey() {
        assertTrue(MapViewUtils.isValidGoogleMapsApiKey("AIzaSyD-example-key"))
    }
}
