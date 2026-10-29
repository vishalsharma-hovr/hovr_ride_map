import SwiftUI
import UIKit

/// Route and marker colours from the host app's theme (light/dark/festive),
/// as ARGB values. Defaults are HOVR's greens, used until the app sends colours.
public struct MapThemeColors: Equatable {
    /// Route line, marker rings and dots.
    public var accent: UInt32 = 0xFF4A_AB24
    /// ETA bubble and tag pill backgrounds.
    var accentStrong: UInt32 = 0xFF2E_7D38
    /// Inner ring of the start/destination icon.
    var accentContainer: UInt32 = 0xFFD0_EEC4
    /// Text and icons on `accent` / `accentStrong`.
    var onAccent: UInt32 = 0xFFFF_FFFF
    /// Address tag and stop marker backgrounds.
    var surface: UInt32 = 0xFFFF_FFFF
    /// Text and icons on `surface`.
    var onSurface: UInt32 = 0xFF1E_1E1E

    /// Colours for the next route or marker drawn. Read and written on the main thread.
    public static var current = MapThemeColors()

    /// Reads ARGB values by token name; missing or invalid tokens keep the HOVR default.
    static func fromArgs(_ args: Any?) -> MapThemeColors {
        guard let colors = args as? [String: Any] else { return MapThemeColors() }
        var theme = MapThemeColors()
        func read(_ key: String) -> UInt32? { (colors[key] as? NSNumber)?.uint32Value }
        theme.accent = read("accent") ?? theme.accent
        theme.accentStrong = read("accentStrong") ?? theme.accentStrong
        theme.accentContainer = read("accentContainer") ?? theme.accentContainer
        theme.onAccent = read("onAccent") ?? theme.onAccent
        theme.surface = read("surface") ?? theme.surface
        theme.onSurface = read("onSurface") ?? theme.onSurface
        return theme
    }
}

extension UInt32 {
    /// This ARGB value as a UIKit colour.
    public var argbUIColor: UIColor {
        UIColor(
            red: CGFloat((self >> 16) & 0xFF) / 255,
            green: CGFloat((self >> 8) & 0xFF) / 255,
            blue: CGFloat(self & 0xFF) / 255,
            alpha: CGFloat((self >> 24) & 0xFF) / 255
        )
    }

    /// This ARGB value as a SwiftUI colour.
    var argbColor: Color { Color(argbUIColor) }
}
