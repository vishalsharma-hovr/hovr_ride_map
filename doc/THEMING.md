# Theming

The host app can carry its light, dark and festive themes onto every native map (home, in-trip and route preview). Theming is app-wide: one call styles all maps, including maps created later.

| Call | What it changes | When it takes effect | Reset |
|------|-----------------|----------------------|-------|
| `setMapStyle(json)` | Google base map (roads, water, labels) | Immediately, on every open map | `setMapStyle(null)` restores each map's default style |
| `setMapColors(colors)` | Route line, marker rings, ETA bubble, address tags, stop markers, HOVR car tint | Routes and markers drawn **after** the call | Send HOVR's colours again (see below) |
| `setCarIcon(png)` | Car marker on every map (nearby drivers and trip car) | The next time each map updates a car marker | `setCarIcon(null)` restores the HOVR car |

Until the app sends anything, each map keeps its default style (see [`setMapStyle`](#setmapstyle)) and HOVR's greens.

## Recommended setup

Call the theme methods when the app theme changes, and **before** showing a map, so its first route and markers are drawn in the right colours.

```dart
import 'package:flutter/services.dart';
import 'package:hovr_ride_map/hovr_ride_map.dart';

Future<void> applyMapTheme(ThemeData theme, {required bool festive}) async {
  final controller = RideMapController.shared;

  // Google map-style JSON list, e.g. exported from the Maps styling wizard.
  final styleJson = theme.brightness == Brightness.dark
      ? await rootBundle.loadString('assets/map_styles/dark.json')
      : null; // null = each map's default look
  await controller.setMapStyle(styleJson);

  await controller.setMapColors(RideMapColors.fromScheme(theme.colorScheme));

  final festiveCar = festive
      ? (await rootBundle.load('assets/cars/festive_car.png')).buffer.asUint8List()
      : null;
  await controller.setCarIcon(festiveCar);
}
```

## `setMapStyle`

- `json` must be a Google Maps style **JSON list** (`[ { "featureType": ... } ]`). Debug builds assert that it starts with `[`.
- A style that Google Maps rejects is logged on the native side and the map keeps its previous look.
- `null` restores each map's default, which differs by platform today:

  | Map | Android default | iOS default |
  |-----|-----------------|-------------|
  | Home | HOVR style | Google standard |
  | In-trip | HOVR style | Google standard |
  | Route preview | Google standard | HOVR style |

  Send a style explicitly if the app needs the same look on both platforms.

## `setMapColors` and `RideMapColors`

`RideMapColors.fromScheme(colorScheme)` maps the app's Material colour scheme onto the six tokens the native code reads:

| Token | `fromScheme` source | Used for | HOVR default |
|-------|---------------------|----------|--------------|
| `accent` | `primary` | Route line, marker rings and dots, HOVR car tint | `#4AAB24` |
| `accentStrong` | `primary` | ETA bubble and tag pill backgrounds | `#275A13` |
| `accentContainer` | `primaryContainer` | Inner ring of the start/destination icon | `#D0EEC4` |
| `onAccent` | `onPrimary` | Text and icons on `accent` / `accentStrong` | `#FFFFFF` |
| `surface` | `surface` | Address tag and stop marker backgrounds | `#FFFFFF` |
| `onSurface` | `onSurface` | Text and icons on `surface` | `#1E1E1E` |

Build `RideMapColors(...)` directly to pick each token yourself (for example a festive palette). Native code ignores a missing or invalid token and keeps HOVR's default for it.

Colours apply to routes and markers drawn after the call. To recolour a route already on screen, redraw it (for example `setRoutePolyline` or `redrawRoutePreview`).

## `setCarIcon`

- `png` is a **top-down car image with the nose pointing up**. It is drawn in its own colours (not tinted) and keeps its aspect ratio, sized to the same length as the HOVR car.
- Bytes that are not a readable image are logged, and the HOVR car is shown.
- `null` restores the HOVR car, tinted with `accent`.
- Debug builds assert that `png` is not empty.

## Platform notes

- Apart from the default map styles above, Android and iOS behave the same. Theme state lives in `MapStylePolicy`, `MapThemeColors` and `HovrCarIcon` / `HovrFestiveCar` on each platform.
- The calls go over the `hovr-ride-map/style` channel (see [Channel contract](CHANNEL_CONTRACT.md)). Like the rest of `RideMapController`, platform errors are logged, not thrown.
