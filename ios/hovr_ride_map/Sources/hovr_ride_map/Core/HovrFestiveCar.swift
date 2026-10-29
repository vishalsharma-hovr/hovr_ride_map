import UIKit

/// The host app's festive car (top-down, nose up), shown instead of the HOVR
/// car on every map, in its own colours. Read and written on the main thread.
enum HovrFestiveCar {
    /// The festive artwork; nil shows the HOVR car.
    private(set) static var image: UIImage?

    /// Bumps whenever `image` changes, so maps know to swap their markers.
    private(set) static var version = 0

    /// Uses `png` as the car; nil or an unreadable image restores the HOVR car.
    static func set(png: Data?) {
        let decoded = png.flatMap { UIImage(data: $0) }
        if png != nil && decoded == nil {
            NSLog("⚠️ [hovr_ride_map] Festive car is not a valid image")
        }
        image = decoded
        version += 1
    }

    /// Size for an image of `imageSize` drawn `length` points long (its height), keeping its shape.
    static func size(length: CGFloat, for imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGSize(width: length, height: length) }
        return CGSize(width: max(1, length * imageSize.width / imageSize.height), height: length)
    }

    /// The festive car drawn `length` points long, or nil when none is set.
    static func icon(length: CGFloat) -> UIImage? {
        guard let image else { return nil }
        let target = size(length: length, for: image.size)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }
}
