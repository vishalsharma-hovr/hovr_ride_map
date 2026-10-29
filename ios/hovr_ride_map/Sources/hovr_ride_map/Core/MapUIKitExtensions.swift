import GoogleMaps
import SwiftUI
import UIKit

extension UIScreen {
    static var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    static var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

/// Route colours from the app theme (`MapThemeColors.current`), HOVR greens by default.
enum HovrMapColors {
    static var routeGreen: UIColor { MapThemeColors.current.accent.argbUIColor }
    static var routeGreenSwiftUI: Color { MapThemeColors.current.accent.argbColor }
    static var routeGreenLightSwiftUI: Color { MapThemeColors.current.accentStrong.argbColor }
    static var routeGreenMutedSwiftUI: Color { MapThemeColors.current.accent.argbColor }
}

/// Disables native Google Maps chrome so only app polylines and the location dot are interactive.
enum MapChromePolicy {
    static func apply(to mapView: GMSMapView) {
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = false
    }

    static func applyDisplayOnly(to mapView: GMSMapView) {
        apply(to: mapView)
        mapView.settings.scrollGestures = true
        mapView.settings.zoomGestures = true
        mapView.settings.rotateGestures = false
        mapView.settings.tiltGestures = false
    }
}
