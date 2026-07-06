import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hovr_ride_map/src/channels/ride_map_channels.dart';
import 'package:hovr_ride_map/src/models/driver_marker.dart';
import 'package:hovr_ride_map/src/models/lat_lng.dart';
import 'package:hovr_ride_map/src/models/ride_map_mode.dart';

/// Typed facade over native ride map method channels.
class RideMapController {
  RideMapController() {
    _rideViewChannel.setMethodCallHandler(_handleNativeCallback);
  }

  final _rideViewChannel = const MethodChannel(RideMapChannels.rideView);
  final _showDriversChannel = const MethodChannel(RideMapChannels.showDrivers);
  final _routesChannel = const MethodChannel(RideMapChannels.routesOnMap);
  final _globalChannel = const MethodChannel(RideMapChannels.globalChannel);

  final _etaController = StreamController<Duration>.broadcast();

  Stream<Duration> get driverEtaUpdates => _etaController.stream;

  /// App-wide singleton used by trip coordinators and legacy channel wrappers.
  static final RideMapController shared = RideMapController();

  Future<void> recenter({bool meetAtPickup = false}) async {
    if (meetAtPickup) {
      await recenterDriverToPickup();
      return;
    }
    if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'recenter-map');
      return;
    }
    await _safeInvoke(_rideViewChannel, 'recenter-map');
  }

  /// Fits the camera to show the driver's current position and the trip
  /// destination — same behavior as [recenterRoutePreview] during in-trip navigation.
  Future<void> recenterDriverToDestination() async {
    await _recenterWithFit('driverToDestination');
  }

  /// Fits the camera to show the driver's current position and the pickup spot.
  Future<void> recenterDriverToPickup() async {
    await _recenterWithFit('driverToPickup');
  }

  Future<void> _recenterWithFit(String fit) async {
    final args = <String, Object>{'fit': fit};
    await _safeInvoke(_rideViewChannel, 'recenter-map', arguments: args);
    if (Platform.isIOS) {
      // iOS polyline/driver updates use global_channel; recenter uses it too for reliability.
      await _safeInvoke(_globalChannel, 'recenter-map', arguments: args);
    }
  }

  Future<void> recenterRoutePreview() async {
    await _safeInvoke(_routesChannel, 'recenter-map');
  }

  Future<void> updateDriverLocation(HovrLatLng position, {double? bearing}) async {
    final payload = <String, Object>{
      'lat': position.latitude,
      'lng': position.longitude,
      'bearing': ?bearing,
    };
    if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'driver-location-channel', arguments: payload);
      return;
    }
    await _safeInvoke(_rideViewChannel, 'driver-location-update', arguments: payload);
  }

  Future<void> setRoutePolyline(String encodedPolyline, {bool force = false}) async {
    final payload = <String, Object>{
      'polyline': encodedPolyline,
      if (force) 'force': true,
    };
    if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'polylines-channel', arguments: payload);
      return;
    }
    await _safeInvoke(_rideViewChannel, 'polylines-channel', arguments: payload);
  }

  /// Removes pickup and rider pins from the in-trip map (heading stage).
  Future<void> clearPickupAndUserMarkers() async {
    await _safeInvoke(_rideViewChannel, 'clear-pickup-user-markers');
    if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'clear-pickup-user-markers');
    }
  }

  Future<void> clearRoute() async {
    if (Platform.isAndroid) {
      await _safeInvoke(_rideViewChannel, 'clear-route');
      await _safeInvoke(_routesChannel, 'clear-route');
    } else if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'clear-route');
    }
  }

  Future<void> setEta(Duration eta) async {
    await _safeInvoke(
      _rideViewChannel,
      'eta-channel',
      arguments: {'eta': eta.inSeconds},
    );
  }

  Future<void> setTripStage(RideMapMode mode) async {
    await _safeInvoke(
      _rideViewChannel,
      'trip-stage',
      arguments: {'tripStage': mode.wireValue},
    );
  }

  Future<void> setTripStops(List<Map<String, Object?>> stops) async {
    await _safeInvoke(
      _rideViewChannel,
      'trip-stops',
      arguments: {'stops': stops},
    );
  }

  Future<void> setTripLocations({
    HovrLatLng? pickup,
    HovrLatLng? dropoff,
    HovrLatLng? user,
  }) async {
    if (pickup != null) {
      await _safeInvoke(
        _rideViewChannel,
        'pickup-location',
        arguments: pickup.toJson(),
      );
    }
    if (dropoff != null) {
      await _safeInvoke(
        _rideViewChannel,
        'drop-off-location',
        arguments: dropoff.toJson(),
      );
    }
    if (user != null) {
      await _safeInvoke(
        _rideViewChannel,
        'user-location',
        arguments: user.toJson(),
      );
    }
  }

  Future<void> showNearbyDrivers(List<DriverMarker> drivers) async {
    await _safeInvoke(
      _showDriversChannel,
      'show-drivers',
      arguments: {
        'nearbyDrivers': drivers.map((d) => d.toJson()).toList(),
      },
    );
  }

  Future<void> showNearbyDriversFromPayload(Map<String, dynamic> payload) async {
    await _safeInvoke(_showDriversChannel, 'show-drivers', arguments: payload);
  }

  void dispose() {
    _rideViewChannel.setMethodCallHandler(null);
    _etaController.close();
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'DRIVER_ETA') {
      final raw = call.arguments;
      final seconds = switch (raw) {
        final int value => value,
        final String value => int.tryParse(value),
        _ => null,
      };
      if (seconds != null) {
        _etaController.add(Duration(seconds: seconds));
      }
    }
    return null;
  }

  Future<void> _safeInvoke(
    MethodChannel channel,
    String method, {
    dynamic arguments,
  }) async {
    try {
      await channel.invokeMethod(method, arguments);
    } on MissingPluginException catch (error, stackTrace) {
      if (method == 'recenter-map') {
        log(
          'RideMapController: no native ride map handler for recenter — stop and full-rebuild the app',
          name: 'RideMapController',
          error: error,
          stackTrace: stackTrace,
        );
      }
    } on PlatformException catch (error, stackTrace) {
      log(
        'RideMapController platform error for $method: ${error.message}',
        name: 'RideMapController',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      log(
        'RideMapController unexpected error for $method',
        name: 'RideMapController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
