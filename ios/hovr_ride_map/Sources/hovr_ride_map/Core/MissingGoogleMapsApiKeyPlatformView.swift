import Flutter
import UIKit

/// Shown when the host app has not configured `GOOGLE_MAPS_API_KEY` in Info.plist.
final class MissingGoogleMapsApiKeyPlatformView: NSObject, FlutterPlatformView {
    private let placeholderView: UIView

    init(frame: CGRect) {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.text =
            "Google Maps API key missing.\nAdd GOOGLE_MAPS_API_KEY to the host app Info.plist."

        let container = UIView(frame: frame)
        container.backgroundColor = .systemGroupedBackground
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        placeholderView = container
        super.init()
    }

    func view() -> UIView {
        placeholderView
    }
}

enum HovrRideMapPlatformViewSupport {
    static func create(
        frame: CGRect,
        configured: () -> FlutterPlatformView
    ) -> FlutterPlatformView {
        guard HovrRideMapResources.isGoogleMapsConfigured else {
            NSLog("⚠️ [hovr_ride_map] Skipping map view — GOOGLE_MAPS_API_KEY is not configured.")
            return MissingGoogleMapsApiKeyPlatformView(frame: frame)
        }
        return configured()
    }
}
