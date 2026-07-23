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

enum HovrMapColors {
    static let routeGreen = UIColor(red: 74 / 255, green: 171 / 255, blue: 36 / 255, alpha: 1)
    static let routeGreenSwiftUI = Color(red: 74 / 255, green: 171 / 255, blue: 36 / 255)
    static let routeGreenLightSwiftUI = Color(red: 0.18, green: 0.49, blue: 0.22)
    static let routeGreenMutedSwiftUI = Color(red: 0.29, green: 0.67, blue: 0.22)
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
