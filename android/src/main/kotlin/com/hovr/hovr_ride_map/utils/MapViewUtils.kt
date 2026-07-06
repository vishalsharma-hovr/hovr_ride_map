package com.hovr.hovr_ride_map.utils

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Log
import android.view.View
import androidx.core.graphics.createBitmap
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object MapViewUtils {
    fun isValidGoogleMapsApiKey(key: String?): Boolean {
        val trimmed = key?.trim().orEmpty()
        if (trimmed.isEmpty()) return false
        if (trimmed.startsWith("$(") && trimmed.endsWith(")")) return false
        if (trimmed.contains("YOUR_API_KEY", ignoreCase = true)) return false
        return true
    }

    fun googleApiKey(context: Context): String {
        return try {
            val appInfo = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
            val raw = appInfo.metaData?.getString("com.google.android.geo.API_KEY")
                ?.takeIf { it.isNotBlank() }
                ?: appInfo.metaData?.getString("GOOGLE_MAPS_API_KEY").orEmpty()
            if (isValidGoogleMapsApiKey(raw)) raw.trim() else ""
        } catch (e: Exception) {
            Log.e("MapViewUtils", "Failed to read Google Maps API key from manifest", e)
            ""
        }
    }

    fun isGoogleMapsConfigured(context: Context): Boolean =
        googleApiKey(context).isNotEmpty()

    fun createBitmapFromView(view: View): Bitmap {
        view.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        val bitmap = createBitmap(view.measuredWidth, view.measuredHeight)
        val canvas = Canvas(bitmap)
        view.draw(canvas)
        return bitmap
    }

    fun getPlaceNameFromCoordinates(context: Context, latitude: Double, longitude: Double): String? {
        val url =
            "https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=${googleApiKey(context)}"
        val client = OkHttpClient()
        val request = Request.Builder().url(url).build()
        return try {
            val response = client.newCall(request).execute()
            val jsonResponse = JSONObject(response.body?.string() ?: "")
            val results = jsonResponse.getJSONArray("results")
            if (results.length() > 0) {
                results.getJSONObject(0).getString("formatted_address")
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e("MapViewUtils", "Geocode failed", e)
            null
        }
    }

    fun formatDurationHMS(input: String): String {
        val secondsToAdd = input.removeSuffix("s").toIntOrNull() ?: return "Invalid input"
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.SECOND, secondsToAdd)
        val sdf = SimpleDateFormat("hh:mm a", Locale.getDefault())
        return sdf.format(calendar.time)
    }

    fun createFixedFontScaleContext(context: Context): Context {
        val config = context.resources.configuration.also {
            it.fontScale = 1.0f
        }
        return context.createConfigurationContext(config)
    }
}
