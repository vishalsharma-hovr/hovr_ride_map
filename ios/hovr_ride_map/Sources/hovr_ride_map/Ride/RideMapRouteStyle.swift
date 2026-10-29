import UIKit

/// HOVR brand green route stroke.
/// Width is a fixed screen size in points — Google Maps does **not** scale
/// `GMSPolyline.strokeWidth` with camera zoom.
enum RideMapRouteStyle {
    /// The app theme's accent (HOVR green `#4AAB24` by default) — matches Android in-trip route.
    static var strokeColor: UIColor { MapThemeColors.current.accent.argbUIColor }

    /// Stroke width in points — mirrors Android `strokeWidthDp` (4–5pt).
    static let strokeWidth: CGFloat = 5

    static let strokeZIndex: Int32 = 100
}
