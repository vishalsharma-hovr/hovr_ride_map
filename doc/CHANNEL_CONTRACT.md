# Channel contract

## `ride-view-channel`

| Method | Arguments | Notes |
|--------|-----------|-------|
| `recenter-map` | none, `{ "fit": "driverToDestination" }`, `{ "fit": "driverToPickup" }`, or `{ "fit": "fullPolyline" }` | Recenters camera; `driverToDestination` fits cab + dropoff; `driverToPickup` fits cab + pickup (includes rider when cab is at pickup); `fullPolyline` zooms out to the **visible** in-trip route (stream leg on map) plus cab when available |
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

## `hovr-ride-map/style`

App-wide theme for every native map. See [Theming](THEMING.md).

| Method | Arguments | Notes |
|--------|-----------|-------|
| `set-map-style` | `{ "json": "<Google map-style JSON list>" \| null }` | Restyles every open and future map; `null` restores each map's default |
| `set-map-colors` | `{ "accent", "accentStrong", "accentContainer", "onAccent", "surface", "onSurface" }` (ARGB `int`s) | Applies to routes and markers drawn afterwards; missing tokens keep HOVR's default |
| `set-car-icon` | `{ "png": <bytes> \| null }` | Festive car for every map; `null` restores the HOVR car |

## Route preview creation params

Read once by `routes-on-map-view` when the view is created.

| Key | Type | Notes |
|-----|------|-------|
| `pickup-latitude`, `pickup-longitude` | `double` | Required |
| `dropoff-latitude`, `dropoff-longitude` | `double` | Required |
| `pickup-location-name`, `dropoff-location-name` | `String` | Address tag text |
| `computeRoutesResponse` | `Map` | Google Routes API response to draw |
| `bottomSheetHeight` | `double` | Sent by `RoutePreviewConfig`; not read by native code today |
| `use-pickup-address-marker` | `bool` (default `false`) | Pickup address marker |
| `use-dropoff-address-marker` | `bool` (default `false`) | Dropoff address marker |
| `disable-user-interaction` | `bool` (default `false`) | Display-only map: scroll and zoom, no rotate or tilt |

## View types

| Constant | Value |
|----------|-------|
| `homeViewType` | `home-view-google-map` |
| `rideViewType` | `hovr-ride-map-view` |
| `legacyRideViewType` | `meet-at-pickup-spot-view` |
| `legacyGoogleMapViewType` | `google-map-view` |
| `routePreviewViewType` | `routes-on-map-view` |

When changing names, update Dart (`lib/src/channels/ride_map_channels.dart`), Kotlin, Swift, and run `dart run tool/check_channel_contract.dart`.
