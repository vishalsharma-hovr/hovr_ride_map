import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:hovr_ride_map/src/channels/ride_map_channels.dart';
import 'package:hovr_ride_map/src/models/festive_map_marker.dart';
import 'package:hovr_ride_map/src/models/driver_marker.dart';
import 'package:hovr_ride_map/src/models/lat_lng.dart';
import 'package:hovr_ride_map/src/models/ride_map_colors.dart';
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
  final _styleChannel = const MethodChannel(RideMapChannels.mapStyle);

  final _etaController = StreamController<Duration>.broadcast();

  /// Driver ETA reported by the native in-trip map (`DRIVER_ETA` callback).
  Stream<Duration> get driverEtaUpdates => _etaController.stream;

  /// App-wide singleton used by trip coordinators and legacy channel wrappers.
  static final RideMapController shared = RideMapController();

  /// Recenters the in-trip map; with [meetAtPickup], fits driver and pickup
  /// like [recenterDriverToPickup].
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

  /// Zooms out so the full in-trip polyline path is visible.
  Future<void> recenterFullPolyline() async {
    await _recenterWithFit('fullPolyline');
  }

  Future<void> _recenterWithFit(String fit) async {
    final args = <String, Object>{'fit': fit};
    await _safeInvoke(_rideViewChannel, 'recenter-map', arguments: args);
    if (Platform.isIOS) {
      // iOS polyline/driver updates use global_channel; recenter uses it too for reliability.
      await _safeInvoke(_globalChannel, 'recenter-map', arguments: args);
    }
  }

  /// Fits the route preview camera to the pickup → dropoff route.
  Future<void> recenterRoutePreview() async {
    await _safeInvoke(_routesChannel, 'recenter-map');
  }

  /// Moves the in-trip driver car to [position]; [bearing] is an optional
  /// heading in degrees from north.
  Future<void> updateDriverLocation(
    HovrLatLng position, {
    double? bearing,
  }) async {
    final payload = <String, Object>{
      'lat': position.latitude,
      'lng': position.longitude,
      'bearing': ?bearing,
    };
    if (Platform.isIOS) {
      await _safeInvoke(
        _globalChannel,
        'driver-location-channel',
        arguments: payload,
      );
      return;
    }
    await _safeInvoke(
      _rideViewChannel,
      'driver-location-update',
      arguments: payload,
    );
  }

  /// Draws the in-trip route from a Google [encodedPolyline]; [force] redraws
  /// even when the polyline is unchanged.
  Future<void> setRoutePolyline(
    String encodedPolyline, {
    bool force = false,
  }) async {
    final payload = <String, Object>{
      'polyline': encodedPolyline,
      if (force) 'force': true,
    };
    if (Platform.isIOS) {
      await _safeInvoke(
        _globalChannel,
        'polylines-channel',
        arguments: payload,
      );
      return;
    }
    await _safeInvoke(
      _rideViewChannel,
      'polylines-channel',
      arguments: payload,
    );
  }

  /// Removes pickup and rider pins from the in-trip map (heading stage).
  Future<void> clearPickupAndUserMarkers() async {
    await _safeInvoke(_rideViewChannel, 'clear-pickup-user-markers');
    if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'clear-pickup-user-markers');
    }
  }

  /// Same as [clearAllRoutes].
  Future<void> clearRoute() async => clearAllRoutes();

  /// Clears the in-trip route and its markers.
  Future<void> clearInTripRoute() async {
    if (Platform.isAndroid) {
      await _safeInvoke(_rideViewChannel, 'clear-route');
    } else if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'clear-route');
    }
  }

  /// Clears the route preview. Android only; no-op on iOS.
  Future<void> clearRoutePreview() async {
    if (Platform.isAndroid) {
      await _safeInvoke(_routesChannel, 'clear-route');
    }
  }

  /// Clears the in-trip route and, on Android, the route preview.
  Future<void> clearAllRoutes() async {
    if (Platform.isAndroid) {
      await _safeInvoke(_rideViewChannel, 'clear-route');
      await _safeInvoke(_routesChannel, 'clear-route');
    } else if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'clear-route');
    }
  }

  /// Removes the driver car from the in-trip map.
  Future<void> clearDriverLocation() async {
    if (Platform.isAndroid) {
      await _safeInvoke(_rideViewChannel, 'clear-driver-location');
    } else if (Platform.isIOS) {
      await _safeInvoke(_globalChannel, 'clear-driver-location');
    }
  }

  /// Redraws the route preview from a Google Routes API response.
  Future<void> redrawRoutePreview({
    required String computeRoutesResponseJson,
  }) async {
    await _safeInvoke(
      _routesChannel,
      'redraw-route-preview',
      arguments: {'computeRoutesResponseJson': computeRoutesResponseJson},
    );
  }

  /// Styles every native map with Google map-style [json] (the host app's
  /// light/dark/festive theme); null restores each map's default look.
  Future<void> setMapStyle(String? json) async {
    assert(json == null || json.trimLeft().startsWith('['), 'map style must be a JSON list');
    await _safeInvoke(_styleChannel, 'set-map-style', arguments: {'json': json});
  }

  /// Draws routes and markers on every native map in the host app's theme
  /// colours (light/dark/festive).
  Future<void> setMapColors(RideMapColors colors) async {
    await _safeInvoke(_styleChannel, 'set-map-colors', arguments: colors.toMap());
  }

  /// Shows [png] (a top-down car, nose up) for every car on the native maps,
  /// in its own colours; null restores the HOVR car in the theme colour.
  Future<void> setCarIcon(Uint8List? png) async {
    assert(png == null || png.isNotEmpty, 'car icon must not be empty');
    await _safeInvoke(_styleChannel, 'set-car-icon', arguments: {'png': png});
  }

  /// Shows [markers] as decorative festive items on the home map, replacing
  /// any shown before; an empty list clears them. They sit under every other
  /// marker and ignore taps.
  Future<void> setFestiveMarkers(List<FestiveMapMarker> markers) async {
    assert(markers.every((m) => m.png.isNotEmpty), 'festive marker images must not be empty');
    await _safeInvoke(
      _styleChannel,
      'set-festive-markers',
      arguments: {'markers': [for (final m in markers) m.toJson()]},
    );
  }

  /// Shows [eta] in the in-trip map's ETA bubble (sent in whole seconds).
  Future<void> setEta(Duration eta) async {
    await _safeInvoke(
      _rideViewChannel,
      'eta-channel',
      arguments: {'eta': eta.inSeconds},
    );
  }

  /// Switches the in-trip map to [mode]. Not needed when rebuilding
  /// `RideMapView` with a new mode, which syncs automatically.
  Future<void> setTripStage(RideMapMode mode) async {
    await _safeInvoke(
      _rideViewChannel,
      'trip-stage',
      arguments: {'tripStage': mode.wireValue},
    );
  }

  /// Shows numbered intermediate stop markers; each stop has `latitude`,
  /// `longitude` and an optional `address`.
  Future<void> setTripStops(List<Map<String, Object?>> stops) async {
    await _safeInvoke(
      _rideViewChannel,
      'trip-stops',
      arguments: {'stops': stops},
    );
  }

  /// Places the pickup, dropoff and rider markers; null values are skipped.
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

  /// Shows [drivers] as car markers on the home map.
  Future<void> showNearbyDrivers(List<DriverMarker> drivers) async {
    await _safeInvoke(
      _showDriversChannel,
      'show-drivers',
      arguments: {'nearbyDrivers': drivers.map((d) => d.toJson()).toList()},
    );
  }

  /// Sends a raw `show-drivers` [payload] (`{"nearbyDrivers": [...]}`) as-is.
  Future<void> showNearbyDriversFromPayload(
    Map<String, dynamic> payload,
  ) async {
    await _safeInvoke(_showDriversChannel, 'show-drivers', arguments: payload);
  }

  /// Stops native callbacks and closes [driverEtaUpdates].
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
