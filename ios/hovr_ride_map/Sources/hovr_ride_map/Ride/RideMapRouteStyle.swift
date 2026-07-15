import UIKit

/// HOVR brand green route stroke.
/// Width is a fixed screen size in points — Google Maps does **not** scale
/// `GMSPolyline.strokeWidth` with camera zoom.
enum RideMapRouteStyle {
    /// HOVR brand green — matches app / Android in-trip route (`#4AAB24`).
    static let strokeColor = UIColor(red: 74 / 255, green: 171 / 255, blue: 36 / 255, alpha: 1)

    /// Stroke width in points — mirrors Android `strokeWidthDp` (4–5pt).
    static let strokeWidth: CGFloat = 5

    static let strokeZIndex: Int32 = 100
}
