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
