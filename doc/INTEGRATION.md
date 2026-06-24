# Integration guide

## 1. Add dependency

**Production (git):**

```yaml
dependencies:
  hovr_ride_map:
    git:
      url: https://github.com/vishalsharma-hovr/hovr_ride_map.git
      ref: v1.0.0
```

**Local plugin development:**

```yaml
dependency_overrides:
  hovr_ride_map:
    path: packages/hovr_ride_map
```

Run `flutter pub get` from the host app root.

## 2. iOS host setup

```ruby
# ios/Podfile
platform :ios, '16.0'
pod 'GoogleMaps'
```

```xml
<!-- ios/Runner/Info.plist -->
<key>GOOGLE_MAPS_API_KEY</key>
<string>YOUR_KEY</string>
```

No `AppDelegate` map registration required — the plugin registers views via `HovrRideMapPlugin`.

## 3. Android host setup

Add Google Maps API key to `AndroidManifest.xml` meta-data (`com.google.android.geo.API_KEY`).

## 4. Use the API

```dart
import 'package:hovr_ride_map/hovr_ride_map.dart';

// Home tab
const HomeMapView()

// In-trip — one view for all stages; pass the current mode from your trip state
RideMapView(mode: currentRideMapMode)

// Driver location, route, ETA (from trip stream / blocs)
await RideMapController.shared.updateDriverLocation(HovrLatLng(lat, lng));
await RideMapController.shared.setRoutePolyline(encodedPolyline);
```

When trip stage changes, rebuild `RideMapView` with the new `RideMapMode` — the plugin pushes the stage to native code only when the mode value changes. The native platform view stays mounted across host rebuilds (stable platform view key, frozen `creationParams`).

## Out of scope (host app)

- Pickup location picker (`pickup_location_map`)
- Google Places autocomplete
- Trip/ride blocs and gRPC
