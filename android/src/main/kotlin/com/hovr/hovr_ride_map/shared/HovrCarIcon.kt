package com.hovr.hovr_ride_map.shared

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.hovr.hovr_ride_map.R

/** Loads the HOVR trip driver car marker — parity with iOS `car-icon` at 28×28 pt. */
object HovrCarIcon {
    /** Matches iOS [RideMapViewRepresentable.createTripCarIcon] / home map icon size. */
    const val DEFAULT_SIZE_DP = 28

    fun bitmapDescriptor(context: Context, sizeDp: Int = DEFAULT_SIZE_DP): BitmapDescriptor {
        val sizePx = (sizeDp * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        val cacheKey = sizePx
        return cache.getOrPut(cacheKey) {
            val source = loadSourceBitmap(context)
            val scaled = if (source.width == sizePx && source.height == sizePx) {
                source
            } else {
                Bitmap.createScaledBitmap(source, sizePx, sizePx, true)
            }
            BitmapDescriptorFactory.fromBitmap(scaled)
        }
    }

    fun clearCache() {
        cache.clear()
    }

    private val cache = mutableMapOf<Int, BitmapDescriptor>()

    private fun loadSourceBitmap(context: Context): Bitmap {
        for (resId in listOf(R.drawable.car_icon, R.drawable.car, R.drawable.ic_car)) {
            BitmapFactory.decodeResource(context.resources, resId)?.let { return it }
        }
        error("HOVR car icon drawable missing")
    }
}
