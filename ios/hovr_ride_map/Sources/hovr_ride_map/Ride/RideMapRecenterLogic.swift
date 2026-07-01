import CoreLocation
import Foundation
import GoogleMaps

/// Camera recenter strategies for the unified ride map.
enum RideMapRecenterLogic {
    struct Context {
        let polylineEncoded: String?
        let driverLocation: [String: Any]
        let carMarker: GMSMarker?
        let dropOffMarker: GMSMarker?
        let defaultZoom: Float
    }

    static func perform(
        on mapView: GMSMapView,
        fit: String?,
        context: Context
    ) -> Bool {
        NSLog("🎯 [hovr_ride_map] performRecenter fit=\(fit ?? "default")")

        if fit == "driverToDestination" {
            if fitDriverToDestination(on: mapView, context: context) { return true }
        }

        if fit == "driverToPickup" {
            if fitDriverToPickup(on: mapView, context: context) { return true }
        }

        return fitDefault(on: mapView, context: context)
    }

    private static func fitDriverToDestination(on mapView: GMSMapView, context: Context) -> Bool {
        guard
            let driver = resolveDriverCoordinate(context: context),
            let destination = resolveDestinationCoordinate(context: context)
        else {
            return fitFullPolyline(on: mapView, encoded: context.polylineEncoded)
        }

        let bounds = GMSCoordinateBounds(coordinate: driver, coordinate: destination)
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 100))
        NSLog("🎯 Recentered driver+destination")
        return true
    }

    private static func fitDriverToPickup(on mapView: GMSMapView, context: Context) -> Bool {
        let driver = resolveDriverCoordinate(context: context)
        let pickup = resolvePickupCoordinate(context: context)

        if let driver, let pickup {
            var bounds = GMSCoordinateBounds(coordinate: driver, coordinate: pickup)
            let spanMeters = CLLocation(latitude: driver.latitude, longitude: driver.longitude)
                .distance(from: CLLocation(latitude: pickup.latitude, longitude: pickup.longitude))
            if spanMeters < 50, let user = TripUserController.shared.coordinate {
                let userCoordinate = CLLocationCoordinate2D(latitude: user.lat, longitude: user.lng)
                bounds = bounds.includingCoordinate(userCoordinate)
            }
            mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 100))
            NSLog("🎯 Recentered driver+pickup")
            return true
        }

        if let pickup {
            mapView.animate(to: GMSCameraPosition.camera(withTarget: pickup, zoom: context.defaultZoom))
            NSLog("🎯 Recentered to pickup")
            return true
        }

        return fitFullPolyline(on: mapView, encoded: context.polylineEncoded)
    }

    private static func fitFullPolyline(on mapView: GMSMapView, encoded: String?) -> Bool {
        guard
            let encoded,
            let path = gmsPath(fromEncodedPolyline: encoded),
            path.count() > 1
        else {
            return false
        }
        let bounds = GMSCoordinateBounds(path: path)
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 100))
        NSLog("🎯 Recentered full route bounds")
        return true
    }

    private static func fitDefault(on mapView: GMSMapView, context: Context) -> Bool {
        if let encoded = context.polylineEncoded,
           !encoded.isEmpty,
           let path = gmsPath(fromEncodedPolyline: encoded),
           path.count() > 1 {
            let firstCoord = path.coordinate(at: 0)
            let camera = GMSCameraPosition.camera(
                withLatitude: firstCoord.latitude,
                longitude: firstCoord.longitude,
                zoom: context.defaultZoom
            )
            mapView.animate(to: camera)
            print("🎯 Recentered to polyline start: \(firstCoord.latitude), \(firstCoord.longitude)")
            return true
        }
        return false
    }

    private static func resolveDriverCoordinate(context: Context) -> CLLocationCoordinate2D? {
        let location = context.driverLocation
        if let lat = coordinateFromChannelValue(location["lat"]),
           let lng = coordinateFromChannelValue(location["lng"]) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        if let marker = context.carMarker {
            return marker.position
        }
        if let encoded = context.polylineEncoded,
           let path = gmsPath(fromEncodedPolyline: encoded),
           path.count() > 0 {
            return path.coordinate(at: 0)
        }
        return nil
    }

    private static func resolveDestinationCoordinate(context: Context) -> CLLocationCoordinate2D? {
        if let marker = context.dropOffMarker {
            return marker.position
        }
        if let dropoff = TripDropoffController.shared.coordinate {
            return CLLocationCoordinate2D(latitude: dropoff.lat, longitude: dropoff.lng)
        }
        if let encoded = context.polylineEncoded,
           let path = gmsPath(fromEncodedPolyline: encoded),
           path.count() > 0 {
            return path.coordinate(at: path.count() - 1)
        }
        return nil
    }

    private static func resolvePickupCoordinate(context: Context) -> CLLocationCoordinate2D? {
        if let pickup = TripPickupController.shared.coordinate {
            return CLLocationCoordinate2D(latitude: pickup.lat, longitude: pickup.lng)
        }
        if let marker = context.dropOffMarker {
            return marker.position
        }
        if let encoded = context.polylineEncoded,
           let path = gmsPath(fromEncodedPolyline: encoded),
           path.count() > 0 {
            return path.coordinate(at: path.count() - 1)
        }
        return nil
    }
}
