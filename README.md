# hovr_ride_map

Native Google Maps platform views and typed ride-map channels for HOVR rider apps.

## Features

- **HomeMapView** — user location, nearby drivers, recenter
- **RideMapView** — unified in-trip map with `RideMapMode` (finding driver, meet at pickup, heading to destination, etc.)
- **RoutePreviewMapView** — pickup → dropoff route preview during choose-a-ride
- **RideMapController** — typed API for driver location, polylines, ETA, trip stage, and route clearing

## Usage

```yaml
dependencies:
  hovr_ride_map:
    path: packages/hovr_ride_map
```

```dart
import 'package:hovr_ride_map/hovr_ride_map.dart';

// Home tab
HomeMapView(key: mapKey)

// In-trip map
RideMapView(mode: RideMapMode.meetAtPickup)

// Controller (singleton)
RideMapController.shared.updateDriverLocation(HovrLatLng(lat, lng));
RideMapController.shared.setRoutePolyline(encodedPolyline);
await RideMapController.shared.clearRoute();
```

## Platform notes

- Android native code lives in this plugin (`com.hovr.hovr_ride_map`).
- iOS platform views are still registered from the host app `Runner` until the iOS native module is fully migrated into this package.
- Pickup-location picker (`pickup_location_map`) remains in the host app by design.

## Manual QA checklist

- [ ] Home map recenter and nearby drivers
- [ ] Each `RideMapMode` during an active trip
- [ ] Route preview map with bottom sheet resize
- [ ] Trip stream driver location + polyline updates
- [ ] Trip cancel / complete clears route

## Development

```bash
cd packages/hovr_ride_map && flutter test
cd android && ./gradlew :hovr_ride_map:testDebugUnitTest
```
