package com.hovr.hovr_ride_map.home

import android.os.AsyncTask
import android.util.Log
import com.google.android.gms.maps.model.LatLng
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

interface SnapToRoadsCallback {
    fun onComplete(snappedPoints: List<LatLng>)
}

fun snapPathToRoads(coordinates: List<LatLng>, apiKey: String, callback: SnapToRoadsCallback) {
    if (coordinates.isEmpty()) {
        callback.onComplete(emptyList())
        return
    }

    val pathParam = coordinates.joinToString("|") { "${it.latitude},${it.longitude}" }
    val encodedPath = URLEncoder.encode(pathParam, "UTF-8")
    val urlString = "https://roads.googleapis.com/v1/snapToRoads?path=$encodedPath&interpolate=true&key=$apiKey"

    object : AsyncTask<Void, Void, List<LatLng>>() {
        override fun doInBackground(vararg params: Void?): List<LatLng> {
            return try {
                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connect()

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val inputStream = connection.inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(inputStream)
                    val snappedPoints = json.optJSONArray("snappedPoints") ?: return emptyList()

                    List(snappedPoints.length()) { i ->
                        val point = snappedPoints.getJSONObject(i)
                        val location = point.getJSONObject("location")
                        LatLng(location.getDouble("latitude"), location.getDouble("longitude"))
                    }
                } else {
                    Log.e("SnapToRoads", "❌ HTTP error code: $responseCode")
                    emptyList()
                }
            } catch (e: Exception) {
                Log.e("SnapToRoads", "❌ Exception: ${e.localizedMessage}")
                emptyList()
            }
        }

        override fun onPostExecute(result: List<LatLng>) {
            callback.onComplete(result)
        }
    }.execute()
}