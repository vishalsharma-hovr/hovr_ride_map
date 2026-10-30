import Flutter
import GoogleMaps
import UIKit

/// Decorative festive items on the home map(s), sent by the host app. Drawn
/// centred, under every other marker, slightly see-through and not tappable,
/// so they never act like real places. Call on the main thread.
final class FestiveMarkers {
    static let shared = FestiveMarkers()

    /// Most items drawn at once, whatever the app sends.
    static let maxMarkers = 12

    /// Pixel density the app renders badges at (`festiveSpotPng`'s default).
    private static let imageScale: CGFloat = 3

    /// One item: where, and its badge image.
    struct Spec {
        let latitude: Double
        let longitude: Double
        let png: Data
    }

    private var specs: [Spec] = []
    // Weak keys: a released map view drops out without an explicit detach.
    private let shown = NSMapTable<GMSMapView, NSMutableArray>.weakToStrongObjects()

    private init() {}

    /// Draws the current items on `mapView` now and on every later `update`.
    func attach(_ mapView: GMSMapView) {
        shown.setObject(NSMutableArray(), forKey: mapView)
        draw(on: mapView)
    }

    /// Replaces the items on every attached map; an empty list clears them.
    func update(arguments: Any?) {
        specs = FestiveMarkers.parse(arguments)
        for mapView in shown.keyEnumerator().allObjects.compactMap({ $0 as? GMSMapView }) {
            draw(on: mapView)
        }
    }

    /// `{"markers": [{"lat", "lng", "png"}]}` → valid items, at most `maxMarkers`.
    static func parse(_ arguments: Any?) -> [Spec] {
        guard let raw = (arguments as? [String: Any])?["markers"] as? [Any] else { return [] }
        let specs = raw.compactMap { entry -> Spec? in
            guard let m = entry as? [String: Any],
                  let lat = (m["lat"] as? NSNumber)?.doubleValue,
                  let lng = (m["lng"] as? NSNumber)?.doubleValue,
                  let png = (m["png"] as? FlutterStandardTypedData)?.data,
                  !png.isEmpty else { return nil }
            return Spec(latitude: lat, longitude: lng, png: png)
        }
        return Array(specs.prefix(maxMarkers))
    }

    private func draw(on mapView: GMSMapView) {
        guard let markers = shown.object(forKey: mapView) else { return }
        for case let marker as GMSMarker in markers {
            marker.map = nil
        }
        markers.removeAllObjects()
        for spec in specs {
            guard let image = UIImage(data: spec.png, scale: FestiveMarkers.imageScale) else {
                NSLog("⚠️ [hovr_ride_map] Skipped a festive marker whose image could not be decoded")
                continue
            }
            let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: spec.latitude, longitude: spec.longitude))
            marker.icon = image
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.opacity = 0.9
            marker.zIndex = -1
            marker.isTappable = false
            marker.map = mapView
            markers.add(marker)
        }
    }
}
