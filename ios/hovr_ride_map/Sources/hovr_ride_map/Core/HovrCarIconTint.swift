import UIKit

/// Paints the car marker in the app theme's colour: the white body takes the
/// tint while dark windows and shading stay. Parity with Android `HovrCarIcon`.
enum HovrCarIconTint {
    /// Multiplies `pixel`'s colour channels by `tint`'s and keeps `pixel`'s alpha. Both ARGB.
    static func multiply(_ pixel: UInt32, tint: UInt32) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            (((pixel >> shift) & 0xFF) * ((tint >> shift) & 0xFF) / 255) << shift
        }
        return (pixel & 0xFF00_0000) | channel(16) | channel(8) | channel(0)
    }

    /// `image` multiplied by `tint`; returns `image` unchanged if it cannot be drawn.
    static func tinted(_ image: UIImage, tint: UInt32) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width, height = cgImage.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = context.data else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Multiplying premultiplied channels gives the same result as straight ones.
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            let argb = UInt32(bytes[i + 3]) << 24 | UInt32(bytes[i]) << 16 | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2])
            let out = multiply(argb, tint: tint)
            bytes[i] = UInt8((out >> 16) & 0xFF)
            bytes[i + 1] = UInt8((out >> 8) & 0xFF)
            bytes[i + 2] = UInt8(out & 0xFF)
        }
        guard let tinted = context.makeImage() else { return image }
        return UIImage(cgImage: tinted, scale: image.scale, orientation: image.imageOrientation)
    }
}
