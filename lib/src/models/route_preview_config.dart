import 'package:flutter/foundation.dart';
import 'package:hovr_ride_map/src/models/lat_lng.dart';

/// Creation params for `RoutePreviewMapView`, read once when the view is created.
@immutable
class RoutePreviewConfig {
  const RoutePreviewConfig({
    required this.pickup,
    required this.dropoff,
    this.pickupName,
    this.dropoffName,
    this.computeRoutesResponseJson,
    this.bottomSheetHeight = 0,
  });

  final HovrLatLng pickup;
  final HovrLatLng dropoff;

  /// Address tag text at the pickup.
  final String? pickupName;

  /// Address tag text at the dropoff.
  final String? dropoffName;

  /// Google Routes API `computeRoutes` response to draw.
  final Map<String, dynamic>? computeRoutesResponseJson;

  /// Sent to native code, which does not read it today.
  final double bottomSheetHeight;

  /// Keys as listed in doc/CHANNEL_CONTRACT.md.
  Map<String, Object?> toCreationParams() => {
    'pickup-latitude': pickup.latitude,
    'pickup-longitude': pickup.longitude,
    'dropoff-latitude': dropoff.latitude,
    'dropoff-longitude': dropoff.longitude,
    if (pickupName != null) 'pickup-location-name': pickupName,
    if (dropoffName != null) 'dropoff-location-name': dropoffName,
    if (computeRoutesResponseJson != null)
      'computeRoutesResponse': computeRoutesResponseJson,
    'bottomSheetHeight': bottomSheetHeight,
  };
}
