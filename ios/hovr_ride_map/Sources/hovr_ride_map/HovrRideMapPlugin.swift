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
        installMapStyleChannel(messenger: messenger)

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

    private static var mapStyleChannel: FlutterMethodChannel?

    /// Host app's light/dark/festive map style → every ride map.
    private static func installMapStyleChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "hovr-ride-map/style", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "set-map-style":
                let json = (call.arguments as? [String: Any])?["json"] as? String
                MapStylePolicy.shared.update(json: json)
            case "set-car-icon":
                // Festive car for every map; nil restores the HOVR car.
                let png = (call.arguments as? [String: Any])?["png"] as? FlutterStandardTypedData
                HovrFestiveCar.set(png: png?.data)
            case "set-map-colors":
                // Applies to routes and markers drawn from now on.
                MapThemeColors.current = MapThemeColors.fromArgs(call.arguments)
            default:
                result(FlutterMethodNotImplemented)
                return
            }
            result(nil)
        }
        mapStyleChannel = channel
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
