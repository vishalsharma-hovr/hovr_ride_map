import XCTest
@testable import hovr_ride_map

final class HovrCarIconTintTests: XCTestCase {
    func testWhiteBodyTakesTheThemeColor() {
        XCTAssertEqual(HovrCarIconTint.multiply(0xFFFF_FFFF, tint: 0xFFFF_7518), 0xFFFF_7518)
    }

    func testDarkWindowsStayDark() {
        XCTAssertEqual(HovrCarIconTint.multiply(0xFF00_0000, tint: 0xFFFF_7518), 0xFF00_0000)
    }

    func testGreyIsShadedAndPixelAlphaIsKept() {
        XCTAssertEqual(HovrCarIconTint.multiply(0x8080_8080, tint: 0xFFFF_7518), 0x8080_3A0C)
    }
}
