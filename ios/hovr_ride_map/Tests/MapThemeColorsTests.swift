import XCTest
@testable import hovr_ride_map

final class MapThemeColorsTests: XCTestCase {
    func testWithoutColorsKeepsHovrGreens() {
        XCTAssertEqual(MapThemeColors.fromArgs(nil), MapThemeColors())
        XCTAssertEqual(MapThemeColors.fromArgs("not a map"), MapThemeColors())
        XCTAssertEqual(MapThemeColors().accent, 0xFF4A_AB24)
    }

    func testUsesTheHostAppThemeColors() {
        let colors = MapThemeColors.fromArgs([
            "accent": NSNumber(value: Int64(0xFFFF_7518)),
            "onSurface": NSNumber(value: Int64(0xFFF2_F3F1)),
        ])

        XCTAssertEqual(colors.accent, 0xFFFF_7518)
        XCTAssertEqual(colors.onSurface, 0xFFF2_F3F1)
        XCTAssertEqual(colors.surface, MapThemeColors().surface)
    }

    func testIgnoresValuesThatAreNotColors() {
        let colors = MapThemeColors.fromArgs(["accent": "orange"])

        XCTAssertEqual(colors.accent, MapThemeColors().accent)
    }

    func testArgbConvertsToUIColorChannels() {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UInt32(0x80FF_0000).argbUIColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 1, accuracy: 0.01)
        XCTAssertEqual(green, 0, accuracy: 0.01)
        XCTAssertEqual(alpha, 128 / 255, accuracy: 0.01)
    }
}
