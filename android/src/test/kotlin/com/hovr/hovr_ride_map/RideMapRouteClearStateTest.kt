package com.hovr.hovr_ride_map

import com.hovr.hovr_ride_map.ride.RideMapRouteClearState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RideMapRouteClearStateTest {
    @Test
    fun shouldSkipRedundantOverlayClear_whenNoRouteState() {
        assertTrue(
            RideMapRouteClearState.shouldSkipRedundantOverlayClear(
                activePolylineCount = 0,
                sourceRoutePathSize = 0,
                polylinePointsSize = 0,
            ),
        )
    }

    @Test
    fun shouldSkipRedundantOverlayClear_falseWhenPolylinesTracked() {
        assertFalse(
            RideMapRouteClearState.shouldSkipRedundantOverlayClear(
                activePolylineCount = 1,
                sourceRoutePathSize = 0,
                polylinePointsSize = 0,
            ),
        )
    }

    @Test
    fun shouldSkipRedundantOverlayClear_falseWhenSourcePathRetained() {
        assertFalse(
            RideMapRouteClearState.shouldSkipRedundantOverlayClear(
                activePolylineCount = 0,
                sourceRoutePathSize = 10,
                polylinePointsSize = 0,
            ),
        )
    }

    @Test
    fun resolveRouteToDraw_honorsPendingChannelEvenWhenExplicitlyCleared() {
        assertEquals(
            "channel_polyline",
            RideMapRouteClearState.resolveRouteToDraw(
                pendingChannelRoute = "channel_polyline",
                savedInMemoryRoute = "saved_polyline",
                routeExplicitlyCleared = true,
            ),
        )
    }

    @Test
    fun resolveRouteToDraw_blocksSavedInMemoryWhenExplicitlyCleared() {
        assertNull(
            RideMapRouteClearState.resolveRouteToDraw(
                pendingChannelRoute = null,
                savedInMemoryRoute = "saved_polyline",
                routeExplicitlyCleared = true,
            ),
        )
    }

    @Test
    fun resolveRouteToDraw_usesSavedInMemoryWhenNotCleared() {
        assertEquals(
            "saved_polyline",
            RideMapRouteClearState.resolveRouteToDraw(
                pendingChannelRoute = null,
                savedInMemoryRoute = "saved_polyline",
                routeExplicitlyCleared = false,
            ),
        )
    }

    @Test
    fun shouldRestoreFromPrefs_falseWhenExplicitlyCleared() {
        assertFalse(
            RideMapRouteClearState.shouldRestoreFromPrefs(
                routeExplicitlyCleared = true,
                prefsRoute = "encoded_polyline",
            ),
        )
    }

    @Test
    fun shouldRestoreFromPrefs_trueWhenNotClearedAndPrefsPresent() {
        assertTrue(
            RideMapRouteClearState.shouldRestoreFromPrefs(
                routeExplicitlyCleared = false,
                prefsRoute = "encoded_polyline",
            ),
        )
    }

    @Test
    fun shouldRestoreFromMemory_trueWhenOrganicPause() {
        assertTrue(
            RideMapRouteClearState.shouldRestoreFromMemory(
                shouldRestoreRoute = true,
                inMemoryRoute = "encoded_polyline",
            ),
        )
    }

    @Test
    fun shouldRestoreFromMemory_falseWhenNotMarkedForRestore() {
        assertFalse(
            RideMapRouteClearState.shouldRestoreFromMemory(
                shouldRestoreRoute = false,
                inMemoryRoute = "encoded_polyline",
            ),
        )
    }

    @Test
    fun resolveResumeRoute_prefersOrganicMemoryOverPrefs() {
        assertEquals(
            "memory_polyline",
            RideMapRouteClearState.resolveResumeRoute(
                routeExplicitlyCleared = false,
                shouldRestoreRoute = true,
                inMemoryRoute = "memory_polyline",
                prefsRoute = "prefs_polyline",
            ),
        )
    }

    @Test
    fun resolveResumeRoute_allowsMemoryDuringExplicitClearWhenOrganicPause() {
        assertEquals(
            "memory_polyline",
            RideMapRouteClearState.resolveResumeRoute(
                routeExplicitlyCleared = true,
                shouldRestoreRoute = true,
                inMemoryRoute = "memory_polyline",
                prefsRoute = null,
            ),
        )
    }

    @Test
    fun resolveResumeRoute_blocksPrefsWhenExplicitlyCleared() {
        assertNull(
            RideMapRouteClearState.resolveResumeRoute(
                routeExplicitlyCleared = true,
                shouldRestoreRoute = false,
                inMemoryRoute = null,
                prefsRoute = "prefs_polyline",
            ),
        )
    }

    @Test
    fun isStaleDraw_trueWhenGenerationAdvanced() {
        assertTrue(RideMapRouteClearState.isStaleDraw(generationAtStart = 1, currentGeneration = 2))
    }

    @Test
    fun isStaleDraw_falseWhenGenerationUnchanged() {
        assertFalse(RideMapRouteClearState.isStaleDraw(generationAtStart = 3, currentGeneration = 3))
    }
}
