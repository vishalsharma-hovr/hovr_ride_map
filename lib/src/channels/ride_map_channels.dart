/// Stable method channel names used by HOVR native map views.
class RideMapChannels {
  RideMapChannels._();

  static const rideView = 'ride-view-channel';
  static const showDrivers = 'show-drivers-location-on-map';
  static const routesOnMap = 'routes-on-map-view';
  static const meetAtPickup = 'meet-at-pickup-spot-view';
  static const globalChannel = 'com.hovr/global_channel';

  /// Host app's map style (light/dark/festive), applied to every native map.
  static const mapStyle = 'hovr-ride-map/style';

  static const homeViewType = 'home-view-google-map';
  static const rideViewType = 'hovr-ride-map-view';
  static const legacyRideViewType = 'meet-at-pickup-spot-view';
  static const legacyGoogleMapViewType = 'google-map-view';
  static const routePreviewViewType = 'routes-on-map-view';
}
