import 'package:flutter/foundation.dart';

/// A decorative festive item on the home map: [png] drawn flat at
/// [latitude]/[longitude], centred, under every other marker and never
/// tappable, so it is not mistaken for a pickup point, driver or place.
@immutable
class FestiveMapMarker {
  const FestiveMapMarker({
    required this.latitude,
    required this.longitude,
    required this.png,
  });

  final double latitude;
  final double longitude;

  /// The badge image (PNG bytes), drawn at its own pixel size.
  final Uint8List png;

  /// `{"lat", "lng", "png"}` as the native maps read it.
  Map<String, Object> toJson() => {'lat': latitude, 'lng': longitude, 'png': png};
}
