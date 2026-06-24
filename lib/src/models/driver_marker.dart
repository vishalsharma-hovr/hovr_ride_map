import 'package:flutter/foundation.dart';
import 'package:hovr_ride_map/src/models/lat_lng.dart';

@immutable
class DriverMarker {
  const DriverMarker({
    required this.id,
    required this.position,
    this.bearingDegrees,
    this.speedMps,
  });

  final String id;
  final HovrLatLng position;
  final double? bearingDegrees;
  final double? speedMps;

  Map<String, Object?> toJson() => {
    'id': id,
    'lat': position.latitude,
    'lng': position.longitude,
    if (bearingDegrees != null) 'bearingDegrees': bearingDegrees,
    if (speedMps != null) 'speed_mps': speedMps,
  };
}
