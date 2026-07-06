# Channel contract

## `ride-view-channel`

| Method | Arguments | Notes |
|--------|-----------|-------|
| `recenter-map` | none, `{ "fit": "driverToDestination" }`, or `{ "fit": "driverToPickup" }` | Recenters camera; `driverToDestination` fits cab + dropoff; `driverToPickup` fits cab + pickup (includes rider when cab is at pickup) |
| `polylines-channel` | `{ "polyline": "<encoded>" }` | Draw route |
| `clear-route` | none | Clears polylines and markers |
| `eta-channel` | `{ "eta": <seconds int> }` | Native ETA display |
| `trip-stage` | `{ "tripStage": "<mode wire value>" }` | Updates `RideMapMode` at runtime (also sent automatically when `RideMapView.mode` changes) |
| `pickup-location` | `{ "lat", "lng" }` | Pickup marker |
| `drop-off-location` | `{ "lat", "lng" }` | Dropoff marker |
| `trip-stops` | `{ "stops": [ { "latitude", "longitude", "address"? } ] }` | Numbered intermediate stop markers |
| `user-location` | `{ "lat", "lng" }` | User marker |
| `driver-location-update` | `{ "lat", "lng", "bearing"? }` | Android driver updates |

### Native → Dart callback

| Method | Arguments |
|--------|-----------|
| `DRIVER_ETA` | seconds (`int` or `String`) |

## `com.hovr/global_channel` (iOS)

| Method | Arguments |
|--------|-----------|
| `recenter-map` | none |
| `driver-location-channel` | `{ "lat", "lng", "bearing"? }` |
| `polylines-channel` | `{ "polyline": "<encoded>" }` |
| `clear-route` | none |

## `show-drivers-location-on-map`

| Method | Arguments |
|--------|-----------|
| `show-drivers` | `{ "nearbyDrivers": [ { "lat", "lng", ... } ] }` |

## `routes-on-map-view`

| Method | Arguments |
|--------|-----------|
| `recenter-map` | none |
| `clear-route` | none |

## View types

| Constant | Value |
|----------|-------|
| `homeViewType` | `home-view-google-map` |
| `rideViewType` | `hovr-ride-map-view` |
| `legacyRideViewType` | `meet-at-pickup-spot-view` |
| `legacyGoogleMapViewType` | `google-map-view` |
| `routePreviewViewType` | `routes-on-map-view` |

When changing names, update Dart (`lib/src/channels/ride_map_channels.dart`), Kotlin, Swift, and run `dart run tool/check_channel_contract.dart`.
