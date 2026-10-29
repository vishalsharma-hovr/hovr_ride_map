import GoogleMaps

/// Host app's map style (light/dark/festive) for every ride map. With no host
/// style, each map keeps its own default (`attach`'s `defaultStyle`, or
/// Google's look when nil). Call on the main thread.
public final class MapStylePolicy {
    public static let shared = MapStylePolicy()

    private var hostJSON: String?
    // Weak keys: a released map view drops out without an explicit detach.
    private let defaults = NSMapTable<GMSMapView, GMSMapStyle>.weakToStrongObjects()
    private let maps = NSHashTable<GMSMapView>.weakObjects()

    private init() {}

    /// Styles `mapView` now and whenever the host app's style changes.
    public func attach(_ mapView: GMSMapView, defaultStyle: GMSMapStyle? = nil) {
        maps.add(mapView)
        if let defaultStyle {
            defaults.setObject(defaultStyle, forKey: mapView)
        }
        style(mapView)
    }

    /// Restyles every attached map; nil restores each map's default look.
    func update(json: String?) {
        hostJSON = json
        for mapView in maps.allObjects {
            style(mapView)
        }
    }

    private func style(_ mapView: GMSMapView) {
        guard let json = hostJSON else {
            mapView.mapStyle = defaults.object(forKey: mapView)
            return
        }
        do {
            mapView.mapStyle = try GMSMapStyle(jsonString: json)
        } catch {
            NSLog("⚠️ [hovr_ride_map] Map style was rejected: \(error)")
        }
    }
}
