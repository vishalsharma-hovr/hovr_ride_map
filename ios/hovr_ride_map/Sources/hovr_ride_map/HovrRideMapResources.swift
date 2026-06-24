import UIKit

/// Resolves images and JSON bundled with the `hovr_ride_map` pod.
enum HovrRideMapResources {
    static var bundle: Bundle {
        let pluginBundle = Bundle(for: HovrRideMapPlugin.self)
        if let url = pluginBundle.url(forResource: "hovr_ride_map", withExtension: "bundle"),
           let resourceBundle = Bundle(url: url) {
            return resourceBundle
        }
        return pluginBundle
    }

    static func image(named name: String) -> UIImage? {
        UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        bundle.url(forResource: name, withExtension: ext)
    }

    /// Reads the host app Google Maps API key from Info.plist.
    static var googleMapsApiKey: String {
        let info = Bundle.main.infoDictionary
        let raw = (info?["GOOGLE_MAPS_API_KEY"] as? String)
            ?? (info?["GMSApiKey"] as? String)
            ?? ""
        return Self.normalizedApiKey(raw)
    }

    static var isGoogleMapsConfigured: Bool {
        !googleMapsApiKey.isEmpty
    }

    static func normalizedApiKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") { return "" }
        if trimmed.uppercased().contains("YOUR_API_KEY") { return "" }
        return trimmed
    }
}
