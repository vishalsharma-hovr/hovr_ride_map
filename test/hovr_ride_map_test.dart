import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('RideMapController.setMapStyle', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(RideMapChannels.mapStyle);
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends the style JSON to every native map', () async {
      await RideMapController().setMapStyle('[{"elementType":"geometry"}]');

      expect(calls.single.method, 'set-map-style');
      expect(calls.single.arguments, {'json': '[{"elementType":"geometry"}]'});
    });

    test('null restores the default map look', () async {
      await RideMapController().setMapStyle(null);

      expect(calls.single.arguments, {'json': null});
    });
  });

  group('RideMapColors', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: Brightness.dark,
    );

    test('fromScheme takes the app theme roles', () {
      final colors = RideMapColors.fromScheme(scheme);

      expect(colors.toMap(), {
        'accent': scheme.primary.toARGB32(),
        'accentStrong': scheme.primary.toARGB32(),
        'accentContainer': scheme.primaryContainer.toARGB32(),
        'onAccent': scheme.onPrimary.toARGB32(),
        'surface': scheme.surface.toARGB32(),
        'onSurface': scheme.onSurface.toARGB32(),
      });
    });

    test('equal schemes give equal colours', () {
      expect(
        RideMapColors.fromScheme(scheme),
        RideMapColors.fromScheme(scheme),
      );
    });
  });

  group('RideMapController.setMapColors', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(RideMapChannels.mapStyle);
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'sends the festive car to every native map, null for the HOVR car',
      () async {
        final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

        await RideMapController().setCarIcon(png);
        await RideMapController().setCarIcon(null);

        expect(calls.map((c) => c.method), ['set-car-icon', 'set-car-icon']);
        expect(calls.first.arguments, {'png': png});
        expect(calls.last.arguments, {'png': null});
      },
    );

    test('sends festive markers to the home map; an empty list clears them', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      const lat = 43.65;
      const lng = -79.38;

      await RideMapController().setFestiveMarkers([
        FestiveMapMarker(latitude: lat, longitude: lng, png: png),
      ]);
      await RideMapController().setFestiveMarkers(const []);

      expect(calls.map((c) => c.method), ['set-festive-markers', 'set-festive-markers']);
      expect(calls.first.arguments, {
        'markers': [
          {'lat': lat, 'lng': lng, 'png': png},
        ],
      });
      expect(calls.last.arguments, {'markers': <Object?>[]});
    });

    test('sends the theme colour tokens to every native map', () async {
      final colors = RideMapColors.fromScheme(
        ColorScheme.fromSeed(seedColor: Colors.green),
      );

      await RideMapController().setMapColors(colors);

      expect(calls.single.method, 'set-map-colors');
      expect(calls.single.arguments, colors.toMap());
    });
  });
}
