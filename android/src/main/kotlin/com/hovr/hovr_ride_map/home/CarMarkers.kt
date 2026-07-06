package com.hovr.hovr_ride_map.home

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.os.SystemClock
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.LinearInterpolator
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.*

class CarMarkers(private val map: GoogleMap, private val icon: BitmapDescriptor) {
    private val markersById = mutableMapOf<String, Marker>()
    private val lastFix = mutableMapOf<String, CarFix>()
    private val lastUpdateTime = mutableMapOf<String, Long>()
    private val moveAnim = mutableMapOf<String, ValueAnimator>()
    private val rotAnim = mutableMapOf<String, ValueAnimator>()
    private var nextPruneAtMs = 0L
    private val minDtMs = (1000.0 / MAX_UPDATE_RATE_HZ).toLong()

    private fun cancelAnims(id: String) {
        moveAnim.remove(id)?.cancel()
        rotAnim.remove(id)?.cancel()
    }

    private fun animateBearing(id: String, marker: Marker, from: Float, toRaw: Float, ms: Long = 200L) {
        val to = shortestHeadingTarget(from, toRaw)
        rotAnim.remove(id)?.cancel()
        val anim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = ms
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener { v ->
                val t = v.animatedFraction
                val b = from + (normalizeDelta(to - from) * t)
                marker.rotation = normalize360(b)
            }
        }
        rotAnim[id] = anim
        anim.start()
    }

    private fun animateMarker(
        id: String,
        marker: Marker,
        start: LatLng,
        end: LatLng,
        targetHeadingDeg: Float?,
        durationMs: Long
    ) {
        cancelAnims(id)
        val anim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = durationMs
            interpolator = LinearInterpolator()
            addUpdateListener { v ->
                val t = v.animatedFraction
                marker.position = slerpLatLng(start, end, t)
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    marker.position = end
                }
            })
        }
        moveAnim[id] = anim
        anim.start()

        targetHeadingDeg?.let { tgt ->
            val rotateMs = durationMs.coerceAtMost(250)
            animateBearing(id, marker, marker.rotation, tgt, rotateMs)
        }
    }

    fun upsert(fixes: List<CarFix>, nowMs: Long = SystemClock.elapsedRealtime()) {
        val minDt = minDtMs

        // prune inactive
        if (nowMs >= nextPruneAtMs) {
            val idsToRemove = lastUpdateTime.filter { nowMs - it.value > DEFAULT_INACTIVE_TIMEOUT_MS }.keys
            for (id in idsToRemove) {
                cancelAnims(id)
                markersById.remove(id)?.remove()
                lastFix.remove(id)
                lastUpdateTime.remove(id)
            }
            nextPruneAtMs = nowMs + DEFAULT_PRUNE_EVERY_MS
        }

        for (fix in fixes) {
            val marker = markersById.getOrPut(fix.id) {
                map.addMarker(
                    MarkerOptions()
                        .position(LatLng(fix.lat, fix.lng))
                        .icon(icon)
                        .flat(true)
                        .anchor(0.5f, 0.5f)
                        .rotation(fix.bearingDeg ?: 0f)
                )!!
            }

            val prev = lastFix[fix.id]
            val start = if (prev == null) LatLng(fix.lat, fix.lng) else LatLng(prev.lat, prev.lng)
            val end = LatLng(fix.lat, fix.lng)
            val dt = (nowMs - (lastUpdateTime[fix.id] ?: 0L)).coerceAtLeast(0L)
            if (dt < minDt) continue

            val dist = distanceMeters(start, end)
            val dtSec = dt / 1000f
            val rawSpeed = (fix.speedMps ?: prev?.speedMps ?: 12f).coerceAtLeast(0.1f)
            val observedSpeed = if (dtSec > 0f) (dist / dtSec).toFloat() else rawSpeed
            val capMps = 10f
            val mixAlpha = 0.30f
            val effSpeed = maxOf(
                (1f - mixAlpha) * minOf(rawSpeed, capMps) + mixAlpha * minOf(observedSpeed, capMps),
                0.1f,
            )
            val expected = effSpeed * dtSec
            val dynTeleport = maxOf(BASE_TELEPORT_DIST_M, expected * TELEPORT_FACTOR)

            when {
                dist > dynTeleport -> {
                    cancelAnims(fix.id)
                    marker.position = end
                    val heading = movementHeading(start, end) ?: fix.bearingDeg
                    heading?.let { marker.rotation = normalize360(it) }
                }
                dist < MICRO_MOVE_THRESHOLD_METERS -> {
                    // Stationary — keep heading stable; ignore noisy server bearing (iOS parity).
                }
                else -> {
                    val duration = calculateAnimationDuration(dist, effSpeed, effSpeed, dt)
                    val heading = movementHeading(start, end)
                    animateMarker(fix.id, marker, start, end, heading, duration)
                }
            }

            lastFix[fix.id] = fix
            lastUpdateTime[fix.id] = nowMs
        }
    }

    fun marker(id: String): Marker? = markersById[id]

    fun remove(id: String) {
        cancelAnims(id)
        markersById.remove(id)?.remove()
        lastFix.remove(id)
        lastUpdateTime.remove(id)
    }
}
