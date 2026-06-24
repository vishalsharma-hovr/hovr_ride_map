import 'package:flutter/foundation.dart';

@immutable
class HovrLatLng {
  const HovrLatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  Map<String, double> toJson() => {'lat': latitude, 'lng': longitude};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HovrLatLng &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
