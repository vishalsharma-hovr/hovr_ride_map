## 1.0.9

- `RideMapController.setFestiveMarkers(List<FestiveMapMarker>)` shows decorative festive items on the home map (under every other marker, never tappable); an empty list clears them.
- iOS: the home map no longer owns `ride-view-channel`. It registers with `RideViewChannelHub` like Android, so closing it no longer removes the channel's handler, and in-trip `recenter-map` calls stop failing with `MissingPluginException`. A contract test keeps the hub as the channel's only owner.

## 1.0.8

- Docs: theming guide, channel contract and dartdoc for the public API.

## 1.0.7

- `RideMapController.setMapStyle(json)` styles every native map (home, in-trip, route preview) with the host app's light/dark/festive map style; null keeps each map's default look.
- `RideMapController.setMapColors(RideMapColors)` draws routes, ETA bubbles, address tags and stop markers in the host app's theme colours; `RideMapColors.fromScheme` builds them from a `ColorScheme`.
- `RideMapController.setCarIcon(png)` shows a festive car on every map in its own colours; null restores the HOVR car, now tinted with the theme accent.
- Docs: new [Theming](doc/THEMING.md) guide; style channel and route-preview creation params in the channel contract.

## 1.0.5

- Route preview: optional pickup/dropoff address markers (`use-pickup-address-marker`, `use-dropoff-address-marker`)
- Route preview: display-only chrome with limited gestures (`disable-user-interaction`) for scheduled-trip/receipt maps
- Android/iOS: `MapChromePolicy.applyDisplayOnly` for scroll/zoom without rotate/tilt

## 1.0.4

- Route in-trip polylines and driver updates to RideMap instead of home/preview handlers
- Add HOVR brand green route stroke with Uber-style casing on Android and iOS
- Improve in-trip stream route restore, recenter, and channel reliability

## 1.0.3

- In-trip recenter: `fullPolyline` fit zooms out to show the entire route path.
- In-trip map: continuously trim completed polyline behind the car as the driver moves.
- Route preview: show intermediate stops with destination-style address tags; tap expands to two lines with ellipsis.
- Native map chrome: disable Google Maps recenter, compass, toolbar, and POI/marker place UI on home, ride, and route-preview maps.
- In-trip ride map: stream-polygon-driven routes, movement-based driver bearing, one-time meet-at-pickup camera fit, and gesture-aware recenter.
- Android ride map: smooth in-trip driver animation via shared `CarMarkers` (matches iOS ride map).
- Android ride map: preserve trip driver marker position when route polyline refreshes.
- Android ride map: skip redundant polyline redraws when encoded route is unchanged.
- Android: fix duplicate Kotlin source-set compile error in plugin `build.gradle.kts`.
- iOS: embed `MapChromePolicy` in `MapUIKitExtensions` so CocoaPods picks it up without a fresh `pod install`.

## 1.0.2

- Android home map: use native `isMyLocationEnabled` blue dot (matches iOS and Google Maps) instead of a custom green marker that flickered on each GPS update.
- Android home map: forward MapView attach/detach lifecycle and resume location tracking after backgrounding.
- Android home map: faster high-accuracy location updates for camera first-fix and recenter.

## 1.0.1

- iOS home map: stabilize nearby-driver bearing to match Android — position-only animation, movement-based heading, no `arcifySegment` synthetic headings.
- iOS ride map: reuse shared `CarMarkers` for in-trip driver marker rotation.

## 1.0.0

- Unified `RideMapPlatformView` for all in-trip stages (`RideMapMode`) on Android and iOS.
- Typed `RideMapController` for driver location, polylines, ETA, trip stage, and nearby drivers.
- `HomeMapView` and `RoutePreviewMapView` surfaces for home tab and choose-a-ride preview.
- Legacy view type aliases (`meet-at-pickup-spot-view`, `google-map-view`) route to the unified ride map.
- Recenter fit modes: `driverToDestination` and `driverToPickup` with iOS dual-channel reliability.
- Extracted `RideMapRecenter`, `RideMapPolylineDecoder` (Android) and `RideMapRecenterLogic` (iOS).