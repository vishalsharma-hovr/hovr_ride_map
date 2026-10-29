//
//  MapGeometryHelpers.swift
//  HOVR
//

import CoreLocation
import Foundation
import GoogleMaps
import SwiftUI
import UIKit

func dismissView() {
    if let windowScene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        if let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            rootViewController.dismiss(animated: true, completion: nil)
        }
    }
}

func snapPathToRoads(
    coordinates: [CLLocationCoordinate2D],
    completion: @escaping ([CLLocationCoordinate2D]) -> Void
) {
    guard !coordinates.isEmpty else {
        completion([])
        return
    }

    let apiKey = HovrRideMapResources.googleMapsApiKey
    guard !apiKey.isEmpty else {
        completion([])
        return
    }
    let baseUrl = "https://roads.googleapis.com/v1/snapToRoads"
    let pathParam = coordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")

    guard let encodedPath = pathParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        completion([])
        return
    }

    let urlString = "\(baseUrl)?path=\(encodedPath)&interpolate=true&key=\(apiKey)"
    guard let url = URL(string: urlString) else {
        completion([])
        return
    }

    let task = URLSession.shared.dataTask(with: url) { data, _, error in
        guard
            let data = data,
            error == nil,
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let snappedPoints = json["snappedPoints"] as? [[String: Any]]
        else {
            print("❌ Roads API error: \(error?.localizedDescription ?? "Unknown error")")
            completion([])
            return
        }

        let snappedCoordinates: [CLLocationCoordinate2D] = snappedPoints.compactMap { point in
            guard
                let location = point["location"] as? [String: Double],
                let lat = location["latitude"],
                let lng = location["longitude"]
            else { return nil }

            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        completion(snappedCoordinates)
    }

    task.resume()
}

func calculateBearing(from start: LatLng, to end: LatLng) -> CLLocationDirection {
    let fromLat = start.latitude.degreesToRadians
    let fromLng = start.longitude.degreesToRadians
    let toLat = end.latitude.degreesToRadians
    let toLng = end.longitude.degreesToRadians
    let dLon = toLng - fromLng
    let y = sin(dLon) * cos(toLat)
    let x = cos(fromLat) * sin(toLat) - sin(fromLat) * cos(toLat) * cos(dLon)
    let radiansBearing = atan2(y, x)
    var degrees = radiansBearing.radiansToDegrees
    degrees = (degrees + 360).truncatingRemainder(dividingBy: 360)
    return degrees
}

func computeBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDegrees {
    let fromLat = from.latitude.degreesToRadians
    let fromLng = from.longitude.degreesToRadians
    let toLat = to.latitude.degreesToRadians
    let toLng = to.longitude.degreesToRadians

    let dLon = toLng - fromLng
    let y = sin(dLon) * cos(toLat)
    let x = cos(fromLat) * sin(toLat) - sin(fromLat) * cos(toLat) * cos(dLon)
    let radiansBearing = atan2(y, x)
    var degrees = radiansBearing.radiansToDegrees
    degrees = (degrees + 360).truncatingRemainder(dividingBy: 360)
    return degrees
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

func addMarker(at position: CLLocationCoordinate2D, on mapView: GMSMapView, isDriver: Bool = false) -> GMSMarker {
    let marker = GMSMarker(position: position)
    if isDriver, let carImage = HovrRideMapResources.image(named: "car-icon") {
        let scale = zoomScale(for: mapView.camera.zoom)
        marker.icon = HovrFestiveCar.icon(length: scale) ?? carImage.resized(to: CGSize(width: scale, height: scale))
    } else {
        marker.icon = GMSMarker.markerImage(with: .red)
    }
    marker.map = mapView
    return marker
}

func zoomScale(for zoomLevel: Float) -> CGFloat {
    let minZoom: Float = 10.0
    let maxZoom: Float = 20.0
    let minSize: CGFloat = 30
    let maxSize: CGFloat = 40

    let clampedZoom = max(minZoom, min(maxZoom, zoomLevel))
    let ratio = (clampedZoom - minZoom) / (maxZoom - minZoom)
    return minSize + CGFloat(ratio) * (maxSize - minSize)
}

func cleanedEncodedPolyline(_ encoded: String) -> String {
    encoded
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\"", with: "")
        .replacingOccurrences(of: "'", with: "")
        .replacingOccurrences(of: "\\\\", with: "\\")
}

func gmsPath(fromEncodedPolyline encoded: String) -> GMSPath? {
    let cleaned = cleanedEncodedPolyline(encoded)
    guard !cleaned.isEmpty else { return nil }
    return GMSPath(fromEncodedPath: cleaned)
}

func coordinateFromChannelValue(_ value: Any?) -> CLLocationDegrees? {
    if let doubleValue = value as? Double { return doubleValue }
    if let intValue = value as? Int { return CLLocationDegrees(intValue) }
    if let number = value as? NSNumber { return number.doubleValue }
    return nil
}

/// Normalizes Flutter channel driver-location payloads (lat/lng may be NSNumber).
func normalizedDriverLocationDict(from raw: [String: Any]) -> [String: Any]? {
    guard
        let lat = coordinateFromChannelValue(raw["lat"]),
        let lng = coordinateFromChannelValue(raw["lng"])
    else {
        return nil
    }
    var normalized: [String: Any] = [
        "lat": lat,
        "lng": lng,
    ]
    if let bearing = coordinateFromChannelValue(raw["bearing"]) {
        normalized["bearing"] = bearing
    }
    return normalized
}

/// Great-circle distance between two coordinates in meters.
func distanceMeters(
    from origin: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D
) -> CLLocationDistance {
    CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
}

/// Index of the path vertex closest to `coordinate`.
func closestIndex(on path: GMSPath, to coordinate: CLLocationCoordinate2D) -> UInt {
    guard path.count() > 0 else { return 0 }

    var bestIndex: UInt = 0
    var bestDistance = CLLocationDistance.greatestFiniteMagnitude
    for index in 0..<path.count() {
        let point = path.coordinate(at: index)
        let distance = distanceMeters(from: coordinate, to: point)
        if distance < bestDistance {
            bestDistance = distance
            bestIndex = index
        }
    }
    return bestIndex
}

/// Builds a route path that starts at the on-path projection of the driver.
/// Never invents long GPS→vertex chords (those draw as straight lines).
func trimmedPath(
    from path: GMSPath,
    startAt driver: CLLocationCoordinate2D,
    duplicateThresholdMeters: CLLocationDistance = 10,
    maxSnapDistanceMeters: CLLocationDistance = 120
) -> GMSMutablePath? {
    guard path.count() > 1 else { return nil }
    guard CLLocationCoordinate2DIsValid(driver) else { return nil }

    guard let snap = closestPointOnPath(on: path, to: driver) else { return nil }
    if snap.distance > maxSnapDistanceMeters {
        let mutable = GMSMutablePath()
        for index in 0..<path.count() {
            mutable.add(path.coordinate(at: index))
        }
        return mutable
    }

    let mutable = GMSMutablePath()
    mutable.add(snap.projected)
    let continueFrom = min(snap.edgeStart + 1, path.count() - 1)
    for index in continueFrom..<path.count() {
        let coordinate = path.coordinate(at: index)
        if mutable.count() == 1,
           distanceMeters(from: snap.projected, to: coordinate) < duplicateThresholdMeters {
            continue
        }
        mutable.add(coordinate)
    }

    guard mutable.count() > 1 else { return nil }
    return mutable
}

/// Projects `point` onto segment a→b.
func projectOntoSegment(
    point: CLLocationCoordinate2D,
    a: CLLocationCoordinate2D,
    b: CLLocationCoordinate2D
) -> CLLocationCoordinate2D {
    let segmentLength = distanceMeters(from: a, to: b)
    if segmentLength < 1 { return a }
    let headingAb = GMSGeometryHeading(a, b)
    let headingAp = GMSGeometryHeading(a, point)
    let distanceAp = distanceMeters(from: a, to: point)
    let angleRad = (headingAp - headingAb) * .pi / 180
    let along = distanceAp * cos(angleRad)
    let fraction = max(0, min(1, along / segmentLength))
    return GMSGeometryInterpolate(a, b, fraction)
}

func closestPointOnPath(
    on path: GMSPath,
    to driver: CLLocationCoordinate2D
) -> (edgeStart: UInt, projected: CLLocationCoordinate2D, distance: CLLocationDistance)? {
    guard path.count() > 1 else { return nil }
    var bestEdge: UInt = 0
    var bestPoint = path.coordinate(at: 0)
    var bestDistance = CLLocationDistance.greatestFiniteMagnitude
    for index in 0..<(path.count() - 1) {
        let a = path.coordinate(at: index)
        let b = path.coordinate(at: index + 1)
        let projected = projectOntoSegment(point: driver, a: a, b: b)
        let distance = distanceMeters(from: driver, to: projected)
        if distance < bestDistance {
            bestDistance = distance
            bestEdge = index
            bestPoint = projected
        }
    }
    return (bestEdge, bestPoint, bestDistance)
}

/// Returns a stable display path: uses the stream leg as-is when the driver is already
/// near the polyline start; otherwise edge-trims without inventing long chords.
func routePathForDisplay(
    from path: GMSPath,
    driver: CLLocationCoordinate2D,
    nearStartThresholdMeters: CLLocationDistance = 80
) -> GMSMutablePath? {
    guard path.count() > 1 else { return nil }
    guard CLLocationCoordinate2DIsValid(driver) else { return nil }

    let pathStart = path.coordinate(at: 0)
    if distanceMeters(from: driver, to: pathStart) < nearStartThresholdMeters {
        let mutable = GMSMutablePath()
        for index in 0..<path.count() {
            mutable.add(path.coordinate(at: index))
        }
        return mutable
    }
    return trimmedPath(from: path, startAt: driver)
}
