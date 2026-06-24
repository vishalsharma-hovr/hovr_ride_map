import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_ride_map/hovr_ride_map.dart';

void main() {
  group('RideMapMode', () {
    test('wireValue round-trips', () {
      for (final mode in RideMapMode.values) {
        expect(RideMapMode.fromWireValue(mode.wireValue), mode);
      }
    });

    test('fromWireValue returns null for unknown values', () {
      expect(RideMapMode.fromWireValue('unknown'), isNull);
      expect(RideMapMode.fromWireValue(null), isNull);
    });
  });

  group('RoutePreviewConfig', () {
    test('toCreationParams includes coordinates', () {
      const config = RoutePreviewConfig(
        pickup: HovrLatLng(43.7, -79.4),
        dropoff: HovrLatLng(43.8, -79.3),
        pickupName: 'Pickup',
        dropoffName: 'Dropoff',
      );

      final params = config.toCreationParams();
      expect(params['pickup-latitude'], 43.7);
      expect(params['pickup-longitude'], -79.4);
      expect(params['dropoff-latitude'], 43.8);
      expect(params['dropoff-longitude'], -79.3);
      expect(params['pickup-location-name'], 'Pickup');
      expect(params['dropoff-location-name'], 'Dropoff');
    });
  });

  group('DriverMarker', () {
    test('toJson includes id and coordinates', () {
      const marker = DriverMarker(
        id: 'driver-1',
        position: HovrLatLng(1, 2),
        bearingDegrees: 90,
      );
      expect(marker.toJson()['id'], 'driver-1');
      expect(marker.toJson()['lat'], 1);
      expect(marker.toJson()['lng'], 2);
      expect(marker.toJson()['bearingDegrees'], 90);
    });
  });
}
