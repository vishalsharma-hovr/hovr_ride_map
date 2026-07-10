package com.hovr.hovr_ride_map.ride

/**
 * Pure helpers for ride-map route clear / restore decisions (unit-testable).
 */
internal object RideMapRouteClearState {
    fun shouldSkipRedundantOverlayClear(
        activePolylineCount: Int,
        sourceRoutePathSize: Int,
        polylinePointsSize: Int,
    ): Boolean =
        activePolylineCount == 0 && sourceRoutePathSize == 0 && polylinePointsSize == 0

    /**
     * Channel/pending routes always win; in-memory/prefs routes are blocked after explicit clear.
     */
    fun resolveRouteToDraw(
        pendingChannelRoute: String?,
        savedInMemoryRoute: String?,
        routeExplicitlyCleared: Boolean,
    ): String? {
        if (!pendingChannelRoute.isNullOrEmpty()) return pendingChannelRoute
        if (routeExplicitlyCleared) return null
        return savedInMemoryRoute?.takeIf { it.isNotEmpty() }
    }

    fun shouldRestoreFromPrefs(
        routeExplicitlyCleared: Boolean,
        prefsRoute: String?,
    ): Boolean = !routeExplicitlyCleared && !prefsRoute.isNullOrEmpty()

    fun shouldRestoreFromMemory(
        shouldRestoreRoute: Boolean,
        inMemoryRoute: String?,
    ): Boolean = shouldRestoreRoute && !inMemoryRoute.isNullOrEmpty()

    /**
     * Resolves which route to restore on resume — memory (organic pause) before prefs.
     */
    fun resolveResumeRoute(
        routeExplicitlyCleared: Boolean,
        shouldRestoreRoute: Boolean,
        inMemoryRoute: String?,
        prefsRoute: String?,
    ): String? {
        if (shouldRestoreFromMemory(shouldRestoreRoute, inMemoryRoute)) {
            return inMemoryRoute
        }
        if (shouldRestoreFromPrefs(routeExplicitlyCleared, prefsRoute)) {
            return prefsRoute
        }
        if (!routeExplicitlyCleared && !inMemoryRoute.isNullOrEmpty()) {
            return inMemoryRoute
        }
        return null
    }

    fun isStaleDraw(generationAtStart: Int, currentGeneration: Int): Boolean =
        generationAtStart != currentGeneration
}
