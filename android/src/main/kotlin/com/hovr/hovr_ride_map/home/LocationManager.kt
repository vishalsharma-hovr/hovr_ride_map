package com.hovr.hovr_ride_map.home

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

internal class LocationManager(private val context: Context) {

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    private var locationCallback: LocationCallback? = null
    private val mainLooper: Looper = Looper.getMainLooper()
    private var latestKnownLocation: Location? = null

    fun setLocationCallback(callback: (Location) -> Unit) {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.locations.forEach { location ->
                    latestKnownLocation = location
                    callback(location)
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun enableLocationTracking() {
        if (!hasLocationPermission()) return

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            15000L
        ).build()

        locationCallback?.let { callback ->
            fusedLocationClient.requestLocationUpdates(locationRequest, callback, mainLooper)
        }
    }

    @SuppressLint("MissingPermission")
    fun getCurrentLocation(callback: (Location?) -> Unit) {
        if (!hasLocationPermission()) {
            callback(null)
            return
        }

        // Recenter should feel instant: use the freshest known fix first.
        latestKnownLocation?.let {
            callback(it)
            return
        }

        fusedLocationClient.lastLocation
            .addOnSuccessListener { lastLocation ->
                if (lastLocation != null) {
                    latestKnownLocation = lastLocation
                    callback(lastLocation)
                } else {
                    requestSingleHighAccuracyLocation(callback)
                }
            }
            .addOnFailureListener {
                requestSingleHighAccuracyLocation(callback)
            }
    }

    @SuppressLint("MissingPermission")
    private fun requestSingleHighAccuracyLocation(callback: (Location?) -> Unit) {
        val singleRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            0L
        ).setMaxUpdates(1).build()

        val singleCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation
                if (location != null) {
                    latestKnownLocation = location
                }
                callback(location)
                fusedLocationClient.removeLocationUpdates(this)
            }
        }

        fusedLocationClient.requestLocationUpdates(singleRequest, singleCallback, mainLooper)
    }

    private fun hasLocationPermission(): Boolean =
        ActivityCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

    fun dispose() {
        locationCallback?.let { callback ->
            fusedLocationClient.removeLocationUpdates(callback)
        }
    }
}
