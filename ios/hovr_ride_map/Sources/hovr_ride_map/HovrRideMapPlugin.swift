import Flutter
import GoogleMaps
import UIKit

/// Registers all `hovr_ride_map` platform views and method channels.
public class HovrRideMapPlugin: NSObject, FlutterPlugin {
    private static var didConfigureMaps = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        configureGoogleMapsIfNeeded()

        let messenger = registrar.messenger()
        RideViewChannelHub.install(messenger: messenger)
        GoogleMapsPlugin.install(messenger: messenger)
        ShowNearByDriverPlugin.install(messenger: messenger)
        GlobalFlutterBridge.shared.setupChannels(messenger: messenger)

        registrar.register(
            HomeViewGoogleMapPlatformViewFactory(messenger: messenger),
            withId: RideMapViewType.home
        )

        let rideFactory = RideMapPlatformViewFactory(messenger: messenger)
        registrar.register(rideFactory, withId: RideMapViewType.ride)
        registrar.register(rideFactory, withId: RideMapViewType.legacyRide)
        registrar.register(rideFactory, withId: RideMapViewType.legacyGoogleMap)
        registrar.register(
            RouteOnGoogleMapViewFactory(messenger: messenger),
            withId: RideMapViewType.routePreview
        )
    }

    private static func configureGoogleMapsIfNeeded() {
        guard !didConfigureMaps else { return }
        didConfigureMaps = true

        let trimmed = HovrRideMapResources.googleMapsApiKey
        guard HovrRideMapResources.isGoogleMapsConfigured else {
            NSLog("⚠️ [hovr_ride_map] GOOGLE_MAPS_API_KEY is missing from the host app Info.plist.")
            return
        }
        GMSServices.provideAPIKey(trimmed)
    }
}

private enum RideMapViewType {
    static let home = "home-view-google-map"
    static let ride = "hovr-ride-map-view"
    static let legacyRide = "meet-at-pickup-spot-view"
    static let legacyGoogleMap = "google-map-view"
    static let routePreview = "routes-on-map-view"
}
