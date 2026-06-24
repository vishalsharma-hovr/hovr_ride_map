import 'package:flutter/foundation.dart';
import 'package:hovr_ride_map/src/models/lat_lng.dart';

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
  final String? pickupName;
  final String? dropoffName;
  final Map<String, dynamic>? computeRoutesResponseJson;
  final double bottomSheetHeight;

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
