import Flutter
import XCTest
@testable import hovr_ride_map

final class FestiveMarkersTests: XCTestCase {
    private let png = FlutterStandardTypedData(bytes: Data([0x89, 0x50, 0x4E, 0x47]))

    func testParseReadsEveryMarker() {
        let specs = FestiveMarkers.parse(["markers": [["lat": 43.65, "lng": -79.38, "png": png]]])
        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs[0].latitude, 43.65)
        XCTAssertEqual(specs[0].longitude, -79.38)
        XCTAssertEqual(specs[0].png, png.data)
    }

    func testEmptyListClears() {
        XCTAssertTrue(FestiveMarkers.parse(["markers": [Any]()]).isEmpty)
    }

    func testBrokenEntriesAreSkipped() {
        let specs = FestiveMarkers.parse(["markers": [
            ["lat": 43.65, "png": png], // no lng
            ["lat": 43.65, "lng": -79.38], // no image
            ["lat": 43.65, "lng": -79.38, "png": FlutterStandardTypedData(bytes: Data())],
            "not a map",
        ]])
        XCTAssertTrue(specs.isEmpty)
    }

    func testCountIsCapped() {
        let one: [String: Any] = ["lat": 1.0, "lng": 2.0, "png": png]
        let specs = FestiveMarkers.parse(["markers": Array(repeating: one, count: FestiveMarkers.maxMarkers + 5)])
        XCTAssertEqual(specs.count, FestiveMarkers.maxMarkers)
    }
}
