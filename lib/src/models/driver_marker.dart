import 'package:flutter/foundation.dart';
import 'package:hovr_ride_map/src/models/lat_lng.dart';

/// A nearby driver shown on the home map.
@immutable
class DriverMarker {
  const DriverMarker({
    required this.id,
    required this.position,
    this.bearingDegrees,
    this.speedMps,
  });

  /// Driver id.
  final String id;
  final HovrLatLng position;

  /// Heading in degrees from north.
  final double? bearingDegrees;

  /// Speed in metres per second.
  final double? speedMps;

  /// Payload entry for `show-drivers`.
  Map<String, Object?> toJson() => {
    'id': id,
    'lat': position.latitude,
    'lng': position.longitude,
    if (bearingDegrees != null) 'bearingDegrees': bearingDegrees,
    if (speedMps != null) 'speed_mps': speedMps,
  };
}
