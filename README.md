# hovr_ride_map

Native Google Maps platform views and typed ride-map channels for HOVR rider apps.

## Features

- **HomeMapView** — user location, nearby drivers, recenter
- **RideMapView** — unified in-trip map for all `RideMapMode` values (one platform view, mode-driven behavior)
- **RoutePreviewMapView** — pickup → dropoff route preview during choose-a-ride
- **RideMapController** — typed API for driver location, polylines, ETA, trip stage, and route clearing

## Usage

```yaml
dependencies:
  hovr_ride_map:
    git:
      url: https://github.com/vishalsharma-hovr/hovr_ride_map.git
      ref: v1.0.0
```

Local development:

```yaml
dependency_overrides:
  hovr_ride_map:
    path: packages/hovr_ride_map
```

```dart
import 'package:hovr_ride_map/hovr_ride_map.dart';

const HomeMapView()

// Pass the current trip stage — mode updates sync to native automatically
RideMapView(mode: RideMapMode.meetAtPickup)

await RideMapController.shared.updateDriverLocation(HovrLatLng(lat, lng));
```

## Documentation

- [Architecture](doc/ARCHITECTURE.md)
- [Channel contract](doc/CHANNEL_CONTRACT.md)
- [Integration](doc/INTEGRATION.md)
- [Map modes](doc/MAP_MODES.md)
- [Contributing](CONTRIBUTING.md)

## Platform notes

- **Android** and **iOS** native code live in this plugin.
- Add `pod 'GoogleMaps'` to your iOS `Podfile` and `GOOGLE_MAPS_API_KEY` to `Info.plist`.
- Minimum iOS deployment target: **16.0**.
- Pickup-location picker (`pickup_location_map`) remains in the host app.

## Development

```bash
cd packages/hovr_ride_map
flutter pub get
dart analyze --fatal-warnings lib test
flutter test
dart run tool/check_channel_contract.dart
cd android && ./gradlew :hovr_ride_map:testDebugUnitTest
```

Publish:

```bash
./tool/publish_to_github.sh v1.0.0
```
