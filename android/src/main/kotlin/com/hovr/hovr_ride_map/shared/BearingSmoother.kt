package com.hovr.hovr_ride_map.shared

class BearingSmoother(private val alpha: Float = 0.35f) {
    private var has = false
    private var last = 0f

    fun reset() {
        has = false
    }

    fun apply(target: Float): Float {
        val t = normalizeDeg(target)
        if (!has) {
            last = t
            has = true
            return last
        }
        last = normalizeDeg(last + alpha * shortestDeltaDeg(last, t))
        return last
    }
}

fun normalizeDeg(x: Float): Float = ((x % 360f) + 360f) % 360f

fun shortestDeltaDeg(from: Float, to: Float): Float {
    var d = normalizeDeg(to) - normalizeDeg(from)
    if (d > 180f) d -= 360f
    if (d < -180f) d += 360f
    return d
}
