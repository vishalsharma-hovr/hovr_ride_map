package com.hovr.hovr_ride_map.shared

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.hovr.hovr_ride_map.R

/** Loads the HOVR trip driver car marker — parity with iOS `car-icon` at 28×28 pt. */
object HovrCarIcon {
    /** Matches iOS [RideMapViewRepresentable.createTripCarIcon] / home map icon size. */
    const val DEFAULT_SIZE_DP = 28

    /**
     * The car marker at [sizeDp]. With [tint] (ARGB), the white body takes the
     * theme colour while dark windows and shading stay; null keeps the artwork.
     */
    fun bitmapDescriptor(context: Context, sizeDp: Int = DEFAULT_SIZE_DP, tint: Int? = null): BitmapDescriptor {
        val sizePx = (sizeDp * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        festiveCar?.let { car ->
            // Festive artwork keeps its own colours and its tall shape.
            return festiveCache.getOrPut(sizePx) {
                val (width, height) = festiveSizePx(sizePx, car.width, car.height)
                BitmapDescriptorFactory.fromBitmap(Bitmap.createScaledBitmap(car, width, height, true))
            }
        }
        return cache.getOrPut(sizePx to tint) {
            val source = loadSourceBitmap(context)
            val scaled = if (source.width == sizePx && source.height == sizePx) {
                source
            } else {
                Bitmap.createScaledBitmap(source, sizePx, sizePx, true)
            }
            BitmapDescriptorFactory.fromBitmap(if (tint == null) scaled else tinted(scaled, tint))
        }
    }

    fun clearCache() {
        cache.clear()
        festiveCache.clear()
    }

    /** The host app's festive car (top-down, nose up), shown instead of the HOVR car; null = HOVR car. */
    var festiveCar: Bitmap? = null
        private set

    /** Bumps whenever [festiveCar] changes, so maps know to swap their markers. */
    var festiveVersion = 0
        private set

    /** Uses [png] as the car marker on every map; null or an unreadable image restores the HOVR car. */
    fun setFestiveCar(png: ByteArray?) {
        val decoded = png?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
        if (png != null && decoded == null) Log.w("HovrCarIcon", "Festive car is not a valid image")
        festiveCar = decoded?.takeIf { it.width > 0 && it.height > 0 }
        festiveCache.clear()
        festiveVersion++
    }

    /** Width and height in px for a [width]×[height] image drawn [lengthPx] long (its height), keeping its shape. */
    fun festiveSizePx(lengthPx: Int, width: Int, height: Int): Pair<Int, Int> {
        if (width <= 0 || height <= 0) return lengthPx to lengthPx
        return (lengthPx * width / height).coerceAtLeast(1) to lengthPx
    }

    /** Multiplies [pixel]'s colour channels by [tint]'s and keeps [pixel]'s alpha. Both ARGB. */
    fun multiply(pixel: Int, tint: Int): Int {
        fun channel(shift: Int) = (((pixel ushr shift) and 0xFF) * ((tint ushr shift) and 0xFF) / 255) shl shift
        return (pixel and 0xFF000000.toInt()) or channel(16) or channel(8) or channel(0)
    }

    private val cache = mutableMapOf<Pair<Int, Int?>, BitmapDescriptor>()
    private val festiveCache = mutableMapOf<Int, BitmapDescriptor>()

    private fun tinted(source: Bitmap, tint: Int): Bitmap {
        val pixels = IntArray(source.width * source.height)
        source.getPixels(pixels, 0, source.width, 0, 0, source.width, source.height)
        for (i in pixels.indices) pixels[i] = multiply(pixels[i], tint)
        return Bitmap.createBitmap(pixels, source.width, source.height, Bitmap.Config.ARGB_8888)
    }

    private fun loadSourceBitmap(context: Context): Bitmap {
        for (resId in listOf(R.drawable.car_icon, R.drawable.car, R.drawable.ic_car)) {
            BitmapFactory.decodeResource(context.resources, resId)?.let { return it }
        }
        error("HOVR car icon drawable missing")
    }
}
