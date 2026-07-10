package com.hovr.hovr_ride_map.ride

import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.hovr.hovr_ride_map.shared.calculateDistanceInMeters
import com.hovr.hovr_ride_map.shared.getDynamicPadding

/** Camera recenter strategies for [RideMapPlatformView]. */
internal object RideMapRecenter {
  private const val TWO_POINT_PADDING_PX = 100

  data class State(
      val lastDriverLatLng: LatLng?,
      val carPosition: LatLng?,
      val startPosition: LatLng?,
      val destPosition: LatLng?,
      val lastDropoffLatLng: LatLng?,
      val lastPickupLatLng: LatLng?,
      val lastUserLatLng: LatLng?,
      val polylinePoints: List<LatLng>,
      /** Full decoded route — used by [fitFullPolyline] when available. */
      val fullRoutePoints: List<LatLng> = emptyList(),
      val followZoom: Float,
  )

  enum class BoundsCameraMode {
    FourArg,
    TwoArg,
  }

  fun selectBoundsCameraMode(mapWidth: Int, mapHeight: Int): BoundsCameraMode? {
    return if (mapWidth > 0 && mapHeight > 0) {
      BoundsCameraMode.FourArg
    } else {
      BoundsCameraMode.TwoArg
    }
  }

  fun resolveDriver(state: State): LatLng? {
    return state.lastDriverLatLng
        ?: state.carPosition
        ?: state.startPosition
        ?: state.polylinePoints.firstOrNull()
  }

  fun resolvePickup(state: State): LatLng? {
    return state.lastPickupLatLng
        ?: state.destPosition
        ?: state.polylinePoints.lastOrNull()
  }

  fun resolveDestination(state: State): LatLng? {
    // Prefer the drawn polyline end so the camera matches the drop-off marker.
    return state.polylinePoints.lastOrNull()
        ?: state.destPosition
        ?: state.lastDropoffLatLng
  }

  /** True when [point] is inside the current camera frustum (including padding). */
  fun isPointVisible(map: GoogleMap, point: LatLng): Boolean {
    return try {
      map.projection.visibleRegion.latLngBounds.contains(point)
    } catch (_: Exception) {
      true
    }
  }

  /**
   * When the driver has left the screen, expand the camera so driver + remaining
   * route destination are framed. Returns true if a camera animation started.
   */
  fun ensureDriverVisible(
      map: GoogleMap,
      state: State,
      mapWidth: Int,
      mapHeight: Int,
  ): Boolean {
    val driver = resolveDriver(state) ?: return false
    if (isPointVisible(map, driver)) return false
    return fitDriverToDestination(map, state, mapWidth, mapHeight)
  }

  /** Drop-off pin always sits on the last vertex of the drawn route. */
  fun dropOffMarkerPosition(path: List<LatLng>, fallbackDropoff: LatLng?): LatLng? {
    return path.lastOrNull() ?: fallbackDropoff
  }

  fun applyFit(
      map: GoogleMap,
      fit: String?,
      state: State,
      mapWidth: Int,
      mapHeight: Int,
  ): Boolean {
    return when (fit) {
      "driverToDestination" -> fitDriverToDestination(map, state, mapWidth, mapHeight)
      "driverToPickup" -> fitDriverToPickup(map, state, mapWidth, mapHeight)
      "fullPolyline" -> fitFullPolyline(map, state, mapWidth, mapHeight)
      else -> false
    }
  }

  fun canFitFullPolyline(state: State): Boolean = routePointsForFullFit(state).size >= 2

  /** Prefer the polyline currently drawn on the map (stream leg) over stored full route. */
  fun routePointsForFullFit(state: State): List<LatLng> {
    return state.polylinePoints.takeIf { it.size >= 2 }
        ?: state.fullRoutePoints.takeIf { it.size >= 2 }
        ?: emptyList()
  }

  fun fitFullPolyline(
      map: GoogleMap,
      state: State,
      mapWidth: Int,
      mapHeight: Int,
  ): Boolean {
    val path = routePointsForFullFit(state)
    if (path.size < 2) return false
    val bounds = LatLngBounds.builder().apply {
      path.forEach { include(it) }
      resolveDriver(state)?.let { include(it) }
    }.build()
    val padding = getDynamicPadding(
        calculateDistanceInMeters(path.first(), path.last())
    )
    return safeAnimateToBounds(map, bounds, padding, mapWidth, mapHeight)
  }

  fun fitPolylineStart(map: GoogleMap, state: State): Boolean {
    val firstPoint = state.polylinePoints.firstOrNull() ?: return false
    map.animateCamera(CameraUpdateFactory.newLatLngZoom(firstPoint, state.followZoom))
    return true
  }

  fun safeAnimateToBounds(
      map: GoogleMap,
      bounds: LatLngBounds,
      padding: Int,
      mapWidth: Int,
      mapHeight: Int,
  ): Boolean {
    val update = when (selectBoundsCameraMode(mapWidth, mapHeight)) {
      BoundsCameraMode.FourArg ->
          CameraUpdateFactory.newLatLngBounds(bounds, mapWidth, mapHeight, padding)
      BoundsCameraMode.TwoArg ->
          CameraUpdateFactory.newLatLngBounds(bounds, padding)
      null -> return false
    }
    return try {
      map.animateCamera(update)
      true
    } catch (_: IllegalStateException) {
      false
    }
  }

  private fun fitDriverToDestination(
      map: GoogleMap,
      state: State,
      mapWidth: Int,
      mapHeight: Int,
  ): Boolean {
    val driver = resolveDriver(state)
    val destination = resolveDestination(state)
    if (driver != null && destination != null) {
      return animateBounds(map, driver, destination, mapWidth, mapHeight)
    }
    return fitFullPolyline(map, state, mapWidth, mapHeight)
  }

  private fun fitDriverToPickup(
      map: GoogleMap,
      state: State,
      mapWidth: Int,
      mapHeight: Int,
  ): Boolean {
    val driver = resolveDriver(state)
    val pickup = resolvePickup(state)
    if (driver != null && pickup != null) {
      val builder = LatLngBounds.builder().include(driver).include(pickup)
      val spanMeters = calculateDistanceInMeters(driver, pickup)
      if (spanMeters < 50.0) {
        state.lastUserLatLng?.let { builder.include(it) }
      }
      return safeAnimateToBounds(
          map,
          builder.build(),
          TWO_POINT_PADDING_PX,
          mapWidth,
          mapHeight,
      )
    }
    if (pickup != null) {
      map.animateCamera(CameraUpdateFactory.newLatLngZoom(pickup, state.followZoom))
      return true
    }
    return fitFullPolyline(map, state, mapWidth, mapHeight)
  }

  private fun animateBounds(
      map: GoogleMap,
      a: LatLng,
      b: LatLng,
      mapWidth: Int,
      mapHeight: Int,
  ): Boolean {
    val bounds = LatLngBounds.builder().include(a).include(b).build()
    return safeAnimateToBounds(map, bounds, TWO_POINT_PADDING_PX, mapWidth, mapHeight)
  }
}
