package com.hovr.hovr_ride_map.shared

import com.google.android.gms.maps.GoogleMap

/** Disables native Google Maps chrome so only app polylines and the location dot are interactive. */
object MapChromePolicy {
    fun apply(googleMap: GoogleMap) {
        googleMap.uiSettings.apply {
            isMyLocationButtonEnabled = false
            isZoomControlsEnabled = false
            isCompassEnabled = false
            isMapToolbarEnabled = false
        }
        googleMap.setOnMarkerClickListener { true }
        googleMap.setOnPoiClickListener { true }
    }

    fun applyDisplayOnly(googleMap: GoogleMap) {
        apply(googleMap)
        googleMap.uiSettings.apply {
            isScrollGesturesEnabled = true
            isZoomGesturesEnabled = true
            isTiltGesturesEnabled = false
            isRotateGesturesEnabled = false
        }
    }
}
