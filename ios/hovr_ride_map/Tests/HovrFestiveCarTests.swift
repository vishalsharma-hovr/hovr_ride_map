import XCTest
@testable import hovr_ride_map

final class HovrFestiveCarTests: XCTestCase {
    override func tearDown() {
        HovrFestiveCar.set(png: nil)
        super.tearDown()
    }

    func testTallCarStaysTallAtTheMarkerLength() {
        XCTAssertEqual(HovrFestiveCar.size(length: 28, for: CGSize(width: 120, height: 240)), CGSize(width: 14, height: 28))
    }

    func testEmptyImageSizeFallsBackToSquare() {
        XCTAssertEqual(HovrFestiveCar.size(length: 28, for: .zero), CGSize(width: 28, height: 28))
    }

    func testInvalidBytesRestoreTheHovrCarAndBumpTheVersion() {
        let before = HovrFestiveCar.version
        HovrFestiveCar.set(png: Data([1, 2, 3]))

        XCTAssertNil(HovrFestiveCar.image)
        XCTAssertNil(HovrFestiveCar.icon(length: 28))
        XCTAssertEqual(HovrFestiveCar.version, before + 1)
    }
}
