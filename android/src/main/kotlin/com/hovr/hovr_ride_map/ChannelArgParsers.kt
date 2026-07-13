package com.hovr.hovr_ride_map

/**
 * Parses values from Flutter method-channel maps.
 *
 * Numbers may arrive as [Double], [Float], or [Int] depending on the Dart encoder
 * and build mode — never cast directly to [Double].
 */
internal object ChannelArgParsers {
    fun latLngFrom(args: Map<*, *>?): Pair<Double, Double>? {
        if (args == null) return null
        val lat = (args["lat"] as? Number)?.toDouble() ?: return null
        val lng = (args["lng"] as? Number)?.toDouble() ?: return null
        return lat to lng
    }

    fun bearingFrom(args: Map<*, *>?): Float? =
        (args?.get("bearing") as? Number)?.toFloat()

    /** Accepts [Boolean] or numeric 0/1 from the method channel. */
    fun boolFrom(args: Map<*, *>?, key: String, default: Boolean = false): Boolean {
        if (args == null) return default
        return when (val value = args[key]) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            else -> default
        }
    }
}
