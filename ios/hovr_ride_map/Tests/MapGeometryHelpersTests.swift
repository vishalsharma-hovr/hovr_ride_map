import GoogleMaps
import XCTest
@testable import hovr_ride_map

final class MapGeometryHelpersTests: XCTestCase {
    /// Classic encoded polyline used across Google Maps examples.
    private let samplePolyline = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"

    func testClosestIndexFindsNearestVertex() {
        guard let path = gmsPath(fromEncodedPolyline: samplePolyline), path.count() > 2 else {
            XCTFail("Expected decodable sample polyline")
            return
        }

        let target = path.coordinate(at: 1)
        XCTAssertEqual(closestIndex(on: path, to: target), 1)
    }

    func testTrimmedPathStartsAtDriver() {
        guard let path = gmsPath(fromEncodedPolyline: samplePolyline), path.count() > 2 else {
            XCTFail("Expected decodable sample polyline")
            return
        }

        let driver = path.coordinate(at: 1)
        guard let trimmed = trimmedPath(from: path, startAt: driver) else {
            XCTFail("Expected trimmed path")
            return
        }

        XCTAssertGreaterThan(trimmed.count(), 1)
        XCTAssertEqual(trimmed.coordinate(at: 0).latitude, driver.latitude, accuracy: 0.00001)
        XCTAssertEqual(trimmed.coordinate(at: 0).longitude, driver.longitude, accuracy: 0.00001)
        XCTAssertLessThanOrEqual(trimmed.count(), path.count())
    }

    func testTrimmedPathReturnsNilForSinglePointPath() {
        let singlePoint = GMSMutablePath()
        singlePoint.add(CLLocationCoordinate2D(latitude: 1, longitude: 1))
        XCTAssertNil(trimmedPath(from: singlePoint, startAt: CLLocationCoordinate2D(latitude: 1, longitude: 1)))
    }

    func testRoutePathForDisplayUsesStreamPathWhenDriverNearStart() {
        guard let path = gmsPath(fromEncodedPolyline: samplePolyline), path.count() > 1 else {
            XCTFail("Expected decodable sample polyline")
            return
        }

        let driver = path.coordinate(at: 0)
        guard let displayPath = routePathForDisplay(from: path, driver: driver) else {
            XCTFail("Expected display path")
            return
        }

        XCTAssertEqual(displayPath.count(), path.count())
        XCTAssertEqual(displayPath.coordinate(at: 0).latitude, path.coordinate(at: 0).latitude, accuracy: 0.00001)
    }
}
