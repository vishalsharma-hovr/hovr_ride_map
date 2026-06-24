package com.hovr.hovr_ride_map.home

import com.google.android.gms.maps.model.LatLng
import kotlin.math.*

// ── Tunables used by CarMarkers
const val MICRO_MOVE_THRESHOLD_METERS = 2.0
const val MIN_ANIM_MS = 150L
const val ABS_MAX_ANIM_MS = 6000L
const val HEADING_DEADZONE_DEG = 7f
const val MAX_UPDATE_RATE_HZ = 5
const val DEFAULT_INACTIVE_TIMEOUT_MS = 15_000L
const val DEFAULT_PRUNE_EVERY_MS = 2_000L
const val BASE_TELEPORT_DIST_M = 200.0
const val TELEPORT_FACTOR = 2.5

data class CarFix(
    val id: String,
    val lat: Double,
    val lng: Double,
    val bearingDeg: Float?,
    val speedMps: Float?,
    val timestampMs: Long
)

data class Waypoint(
    val lat: Double,
    val lng: Double,
    val bearingDeg: Float
)

fun wp(lat: Double, lng: Double, bearingDeg: Float) = Waypoint(lat, lng, bearingDeg)

// Helpers used by CarMarkers
fun distanceMeters(a: LatLng, b: LatLng): Double {
    val dx = (b.longitude - a.longitude) * 111_320.0 * cos(Math.toRadians((a.latitude + b.latitude) / 2.0))
    val dy = (b.latitude - a.latitude) * 110_540.0
    return sqrt(dx * dx + dy * dy)
}

fun normalize360(deg: Float) = ((deg % 360f) + 360f) % 360f

fun normalizeDelta(d: Float): Float {
    var x = (d + 540f) % 360f - 180f
    if (x < -180f) x += 360f
    return x
}

fun shortestHeadingTarget(from: Float, to: Float): Float {
    val df = normalizeDelta(to - from)
    return normalize360(from + df)
}

// Great-circle interpolation
fun slerpLatLng(a: LatLng, b: LatLng, t: Float): LatLng {
    val lat1 = Math.toRadians(a.latitude)
    val lng1 = Math.toRadians(a.longitude)
    val lat2 = Math.toRadians(b.latitude)
    val lng2 = Math.toRadians(b.longitude)

    val dLat = lat2 - lat1
    val dLng = lng2 - lng1
    val sinHalfD = sqrt(sin(dLat / 2).pow(2.0) + cos(lat1) * cos(lat2) * sin(dLng / 2).pow(2.0))
    val d = 2 * asin(sinHalfD)
    if (d == 0.0) return a

    val A = sin((1 - t) * d) / sin(d)
    val B = sin(t * d) / sin(d)

    val x = A * cos(lat1) * cos(lng1) + B * cos(lat2) * cos(lng2)
    val y = A * cos(lat1) * sin(lng1) + B * cos(lat2) * sin(lng2)
    val z = A * sin(lat1) + B * sin(lat2)

    val outLat = Math.toDegrees(atan2(z, sqrt(x * x + y * y)))
    val outLng = Math.toDegrees(atan2(y, x))
    return LatLng(outLat, outLng)
}
private const val SPEED_SLOWDOWN = 1.8f
fun calculateAnimationDuration(
    distanceMeters: Double,
    speedMps: Float?,
    previousSpeedMps: Float?,
    timeSinceLastUpdateMs: Long
): Long {
    val speed = ((speedMps ?: previousSpeedMps ?: 10.0f) / SPEED_SLOWDOWN).coerceAtLeast(0.1f)
//    val speed = (speedMps ?: previousSpeedMps ?: 10.0f).coerceAtLeast(0.1f)
    val idealMs = ((distanceMeters / speed) * 1000.0).toLong()
    val cadenceCap = (timeSinceLastUpdateMs * 0.9).toLong().coerceAtLeast(MIN_ANIM_MS)
    val cadenceBound = cadenceCap.coerceAtMost(ABS_MAX_ANIM_MS)
    val bufferedIdeal = (idealMs * 1.05).toLong()
    return bufferedIdeal.coerceAtMost(cadenceBound).coerceIn(MIN_ANIM_MS, ABS_MAX_ANIM_MS)
}

// ─────────────────────────────────────────────────────────────────────────────
// Safely convert the generic "nearbyDrivers" payload into CarFix list
// (works with speed in m/s or km/h; bearing optional)
// ─────────────────────────────────────────────────────────────────────────────
//fun parseNearbyDrivers(raw: List<*>): List<CarFix> {
//    val fixes = ArrayList<CarFix>(raw.size)
//    val nowWallClock = System.currentTimeMillis()
//
//    for (item in raw) {
//        val m = item as? Map<*, *> ?: continue
//
//        val id = m["id"]?.toString() ?: continue
//        val lat = (m["lat"] as? Number)?.toDouble() ?: continue
//        val lng = (m["lng"] as? Number)?.toDouble() ?: continue
//
//        val bearingDeg = (m["bearing"] as? Number ?: m["bearingDeg"] as? Number)?.toFloat()
//
//        val speedMps = when (val s = m["speed_mps"] ?: m["speedMps"] ?: m["speed"]) {
//            is Number -> s.toFloat()
//            else -> {
//                val kmh = m["speed_kmh"] ?: m["speedKmh"]
//                if (kmh is Number) (kmh.toFloat() / 3.6f) else null
//            }
//        }
//
//        val tsMs = (m["timestampMs"] as? Number)?.toLong()
//            ?: (m["ts"] as? Number)?.toLong()
//            ?: nowWallClock
//
//        fixes += CarFix(
//            id = id,
//            lat = lat,
//            lng = lng,
//            bearingDeg = bearingDeg,
//            speedMps = speedMps,
//            timestampMs = tsMs
//        )
//    }
//    return fixes
//}

fun parseNearbyDrivers(raw: List<*>): List<CarFix> {
    val fixes = ArrayList<CarFix>(raw.size)
    val now = System.currentTimeMillis()

    fun f(v: Any?): Float? = when (v) {
        is Number -> v.toFloat()
        is String -> v.trim().trimEnd('f','F').toFloatOrNull()
        else -> null
    }
    fun d(v: Any?): Double? = when (v) {
        is Number -> v.toDouble()
        is String -> v.trim().trimEnd('f','F').toDoubleOrNull()
        else -> null
    }
    fun extractLatLng(m: Map<*,*>): Pair<Double, Double>? {
        // top-level lat/lng or latitude/longitude
        val latTop = d(m["lat"] ?: m["latitude"])
        val lngTop = d(m["lng"] ?: m["longitude"])
        if (latTop != null && lngTop != null) return latTop to lngTop

        // nested in position/pos/location
        val pos = (m["position"] as? Map<*, *>) ?: (m["pos"] as? Map<*, *>) ?: (m["location"] as? Map<*, *>)
        if (pos != null) {
            val lat = d(pos["lat"] ?: pos["latitude"])
            val lng = d(pos["lng"] ?: pos["longitude"])
            if (lat != null && lng != null) return lat to lng
        }
        return null
    }

    for (item in raw) {
        val m = item as? Map<*, *> ?: continue

        val id = (m["id"] ?: m["driverId"] ?: m["driver_id"])?.toString() ?: continue
        val ll = extractLatLng(m) ?: continue

        val bearingRaw = m["bearingDegrees"] ?: m["bearingDegrees"] ?: m["headingDeg"] ?: m["heading"]
        ?: (m["position"] as? Map<*, *>)?.get("bearingDeg")
        val bearing = f(bearingRaw)?.let { normalize360(it) }

        var speedMps: Float? = when (val s = m["speed_mps"] ?: m["speedMps"] ?: m["speed"]) {
            null -> null
            else -> f(s)
        }
        if (speedMps == null) {
            val kmh = m["speed_kmh"] ?: m["speedKmh"]
            ?: (m["velocity"] as? Map<*, *>)?.get("kmh")
            speedMps = f(kmh)?.div(3.6f)
        }

        val tsAny = m["timestampMs"] ?: m["ts"] ?: m["timestamp"]
        val ts = when (tsAny) {
            is Number -> {
                val v = tsAny.toLong()
                if (v < 1_000_000_000_000L) v * 1000 else v // seconds → ms if needed
            }
            is String -> tsAny.toLongOrNull() ?: now
            else -> now
        }

        fixes += CarFix(
            id = id,
            lat = ll.first,
            lng = ll.second,
            bearingDeg = bearing,
            speedMps = speedMps,
            timestampMs = ts
        )
    }
    return fixes
}
