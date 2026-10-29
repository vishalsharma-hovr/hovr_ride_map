/// Stable method channel names used by HOVR native map views.
class RideMapChannels {
  RideMapChannels._();

  /// In-trip map: recenter, route, ETA, trip stage, trip locations.
  static const rideView = 'ride-view-channel';

  /// Home map: nearby driver markers.
  static const showDrivers = 'show-drivers-location-on-map';

  /// Route preview: recenter, clear and redraw.
  static const routesOnMap = 'routes-on-map-view';

  /// Legacy in-trip channel name, kept for migration.
  static const meetAtPickup = 'meet-at-pickup-spot-view';

  /// iOS in-trip channel for driver location, route and recenter.
  static const globalChannel = 'com.hovr/global_channel';

  /// Host app's map style (light/dark/festive), applied to every native map.
  static const mapStyle = 'hovr-ride-map/style';

  /// Platform view type of `HomeMapView`.
  static const homeViewType = 'home-view-google-map';

  /// Platform view type of `RideMapView`.
  static const rideViewType = 'hovr-ride-map-view';

  /// Legacy alias of [rideViewType], kept for migration.
  static const legacyRideViewType = 'meet-at-pickup-spot-view';

  /// Legacy alias of [rideViewType], kept for migration.
  static const legacyGoogleMapViewType = 'google-map-view';

  /// Platform view type of `RoutePreviewMapView`.
  static const routePreviewViewType = 'routes-on-map-view';
}
