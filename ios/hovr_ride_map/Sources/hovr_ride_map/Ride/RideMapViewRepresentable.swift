    //
    //  GM-View-Representable.swift
    //  HOVR
    //
    //  Created by Vishal Sharma on 06/12/24.
    //

import CoreLocation
import Foundation
import GoogleMaps
import SwiftUI
import Combine
import UIKit

    // MARK: - RideMapViewRepresentable

struct RideMapViewRepresentable: UIViewRepresentable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let zoom: Float
    let locationManager: LocationManager
    let tripStage: String

    @ObservedObject var controller: RecenterMapController
    @ObservedObject var polylineController: PolylineController
    @ObservedObject var driverLocation: DriverLocationController

    init(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        zoom: Float,
        locationManager: LocationManager,
        controller: RecenterMapController,
        polylineController: PolylineController,
        driverLocation: DriverLocationController,
        tripStage: String
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.zoom = zoom
        self.locationManager = locationManager
        self.controller = controller
        self.polylineController = polylineController
        self.driverLocation = driverLocation
        self.tripStage = tripStage
    }
    
        // MARK: - Coordinator
    
    class Coordinator: NSObject {
        var parent: RideMapViewRepresentable
        var mapView: GMSMapView?
        var cancellables = Set<AnyCancellable>()
        var activePolyline: GMSPolyline?
        var traveledPolyline: GMSPolyline?
        var lastProcessedPolyline: String = ""
        var sourceRoutePath: GMSPath?
        var hasFittedCameraToRoute = false
        var userHasInteractedWithMap = false

        var dropOffMarker: GMSMarker?
        var stopMarkers: [GMSMarker] = []

        private let tripDriverId = "trip-driver"
        private var carMarkers: CarMarkers?
        private var lastDriverCoordinate: CLLocationCoordinate2D?
        private var pendingDriverLocation: [String: Any]?

        /// Used by recenter logic — backed by [CarMarkers].
        var carMarker: GMSMarker? {
            carMarkers?.marker(for: tripDriverId)
        }

        func bindCarMarkers(on mapView: GMSMapView) {
            if carMarkers == nil {
                let carImage = Self.createTripCarIcon()
                carMarkers = CarMarkers(map: mapView, icon: carImage)
            }
            replayPendingDriverFixIfNeeded()
        }

        func replayPendingDriverFixIfNeeded() {
            let location = pendingDriverLocation ?? parent.driverLocation.driverLocation
            guard !location.isEmpty else { return }
            restorePersistedDriverFix(from: location)
            pendingDriverLocation = nil
        }

        /// Matches [HomeViewGoogleMapIOS.createCarMarkers] icon sizing (28×28 pt).
        private static func createTripCarIcon() -> UIImage {
            let iconSize = CGSize(width: 28, height: 28)
            let iconNames = ["car-icon", "car_icon", "carIcon", "car"]
            for name in iconNames {
                if let img = HovrRideMapResources.image(named: name),
                   let scaled = img.resized(to: iconSize) {
                    return scaled
                }
            }
            return fallbackTripCarIcon()
        }

        private static func fallbackTripCarIcon() -> UIImage {
            let size = CGSize(width: 28, height: 28)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            defer { UIGraphicsEndImageContext() }

            let context = UIGraphicsGetCurrentContext()
            context?.setFillColor(UIColor.systemBlue.cgColor)
            context?.fillEllipse(in: CGRect(x: 6, y: 6, width: 16, height: 16))
            context?.setFillColor(UIColor.white.cgColor)
            context?.fillEllipse(in: CGRect(x: 10, y: 10, width: 8, height: 8))

            return UIGraphicsGetImageFromCurrentImageContext() ?? emergencyTripCarIcon()
        }

        private static func emergencyTripCarIcon() -> UIImage {
            let size = CGSize(width: 28, height: 28)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                UIColor.systemBlue.setFill()
                UIBezierPath(ovalIn: CGRect(x: 6, y: 6, width: 16, height: 16)).fill()
            }
        }

        /// Restores the driver car marker from persisted location after map attach.
        func restorePersistedDriverFix(from location: [String: Any]) {
            guard
                let normalized = normalizedDriverLocationDict(from: location),
                let lat = normalized["lat"] as? Double,
                let lng = normalized["lng"] as? Double
            else {
                return
            }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            upsertTripDriver(coordinate: coordinate, location: normalized)
        }

        private func upsertTripDriver(
            coordinate: CLLocationCoordinate2D,
            location: [String: Any],
            seedBearing: Float? = nil
        ) {
            guard let normalized = normalizedDriverLocationDict(from: location) else { return }
            lastDriverCoordinate = coordinate
            guard let carMarkers else {
                pendingDriverLocation = normalized
                return
            }
            pendingDriverLocation = nil
            let bearing = coordinateFromChannelValue(normalized["bearing"]).map { Float($0) }
                ?? seedBearing
            let fix = CarFix(
                id: tripDriverId,
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                bearingDeg: bearing,
                speedMps: 12,
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
            )
            carMarkers.upsert(fixes: [fix])
            trimCompletedPolylineBehindDriver()
        }

        /// Drops completed route behind the car so only the remaining path is drawn.
        private func trimCompletedPolylineBehindDriver() {
            guard let mapView, let sourcePath = sourceRoutePath, let driver = lastDriverCoordinate else {
                return
            }
            guard let displayPath = routePathForDisplay(from: sourcePath, driver: driver) else {
                return
            }
            updateActivePolyline(path: displayPath, on: mapView)
        }
        
        func performRecenterRequest(fit: String?) {
            guard let mapView else {
                NSLog("⚠️ [hovr_ride_map] performRecenterRequest: mapView is nil")
                return
            }
            userHasInteractedWithMap = false
            parent.performRecenter(
                on: mapView,
                coordinator: self,
                fit: fit
            )
        }

        var displayedPolylineCoordinates: [CLLocationCoordinate2D] {
            guard let path = activePolyline?.path else { return [] }
            var coordinates: [CLLocationCoordinate2D] = []
            for index in 0..<path.count() {
                coordinates.append(path.coordinate(at: index))
            }
            return coordinates
        }
        
        init(_ parent: RideMapViewRepresentable) {
            self.parent = parent
            super.init()

            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.autoFitFullPolylineOnForeground()
            }

            parent.controller.$shouldRecenter
                .receive(on: DispatchQueue.main)
                .sink { [weak self] shouldRecenter in
                    guard shouldRecenter,
                          let self,
                          let mapView = self.mapView else { return }

                    self.userHasInteractedWithMap = false
                    self.parent.performRecenter(
                        on: mapView,
                        coordinator: self,
                        fit: self.parent.controller.recenterFit
                    )
                    self.parent.controller.shouldRecenter = false
                    self.parent.controller.recenterFit = nil
                }
                .store(in: &cancellables)

            parent.polylineController.$polyline
                .removeDuplicates { oldValue, newValue in
                    let oldPolyline = oldValue["polyline"] as? String ?? ""
                    let newPolyline = newValue["polyline"] as? String ?? ""
                    let oldForce = oldValue["force"] as? Bool ?? false
                    let newForce = newValue["force"] as? Bool ?? false
                    return oldPolyline == newPolyline && oldForce == newForce
                }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] dict in
                    guard let self, let mapView = self.mapView else { return }

                    let encoded = dict["polyline"] as? String ?? ""
                    let force = dict["force"] as? Bool ?? false

                    if encoded.isEmpty {
                        self.clearRouteOverlays(on: mapView)
                        return
                    }

                    if force {
                        self.lastProcessedPolyline = ""
                    }

                    self.applyDriverRoute(
                        encoded: encoded,
                        on: mapView,
                        fitCamera: false,
                        force: force
                    )
                }
                .store(in: &cancellables)

            parent.driverLocation.$driverLocation
                .receive(on: DispatchQueue.main)
                .sink { [weak self] location in
                    guard let self else { return }
                    if location.isEmpty {
                        self.pendingDriverLocation = nil
                        self.lastDriverCoordinate = nil
                        self.carMarkers?.marker(for: self.tripDriverId)?.map = nil
                        return
                    }
                    guard
                        let normalized = normalizedDriverLocationDict(from: location),
                        let lat = normalized["lat"] as? Double,
                        let lng = normalized["lng"] as? Double
                    else {
                        return
                    }
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    self.upsertTripDriver(coordinate: coordinate, location: normalized)
                }
                .store(in: &cancellables)

            TripStageController.shared.$tripStage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] stage in
                    guard let self else { return }
                    let replayStages = ["headingToDestination", "meetAtPickup", "driverWaitingAtPickup"]
                    if replayStages.contains(stage) {
                        self.lastProcessedPolyline = ""
                    }
                    if stage == "headingToDestination" ||
                        stage == "meetAtPickup" ||
                        stage == "driverWaitingAtPickup" {
                        self.hasFittedCameraToRoute = false
                    }
                }
                .store(in: &cancellables)

            TripStopsController.shared.$stops
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self, let mapView = self.mapView else { return }
                    self.redrawStopMarkers(on: mapView)
                }
                .store(in: &cancellables)
        }
        
        deinit {
            RideMapRecenterRegistry.shared.unbind(coordinator: self)
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
            activePolyline?.map = nil
            traveledPolyline?.map = nil
            carMarker?.map = nil
            dropOffMarker?.map = nil
            stopMarkers.forEach { $0.map = nil }
            stopMarkers.removeAll()
            print("✅ Coordinator deallocated")
        }
        
            // MARK: - Add Marker

        func addDropOffMarker(at position: CLLocationCoordinate2D, on mapView: GMSMapView) {
            dropOffMarker?.map = nil

            let marker = GMSMarker(position: position)
            if let dropImage = HovrRideMapResources.image(named: "drop-off-marker") {
                marker.icon = dropImage.resized(to: CGSize(width: 30, height: 30))
            } else {
                marker.icon = GMSMarker.markerImage(with: .blue)
            }
            marker.isTappable = false
            marker.map = mapView
            self.dropOffMarker = marker
        }

        func redrawStopMarkers(on mapView: GMSMapView) {
            stopMarkers.forEach { $0.map = nil }
            stopMarkers.removeAll()

            for stop in TripStopsController.shared.stops {
                let host = UIHostingController(rootView: StopPinMarkerView(stopNumber: stop.index))
                host.view.backgroundColor = .clear
                host.view.frame = CGRect(x: 0, y: 0, width: 28, height: 28)

                let marker = GMSMarker(
                    position: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng)
                )
                marker.iconView = host.view
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.title = stop.address.isEmpty ? "Stop \(stop.index)" : stop.address
                marker.isTappable = false
                marker.map = mapView
                stopMarkers.append(marker)
            }
        }

            // MARK: - Zoom Scale Calculation

        func calculateBearing(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDirection {
            let lat1 = origin.latitude.toRadians()
            let lon1 = origin.longitude.toRadians()
            let lat2 = destination.latitude.toRadians()
            let lon2 = destination.longitude.toRadians()
            
            let deltaLon = lon2 - lon1
            let y = sin(deltaLon) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
            let initialBearing = atan2(y, x)
            
            var bearing = initialBearing.toDegrees()
            bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
            return bearing
        }
        
            //MARK: CENTER CAMERA ON FIRST COORDINATE
        func centerCameraOnFirstCoordinate(on mapView: GMSMapView, zoom: Float) {
            guard
                let encoded = parent.polylineController.polyline["polyline"] as? String,
                !encoded.isEmpty
            else {
                print("⚠️ No polyline to center on.")
                return
            }
            
            let cleaned = encoded
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "\\\\", with: "\\")
            
            guard let path = GMSPath(fromEncodedPath: cleaned), path.count() > 1 else {
                print("❌ Failed to decode polyline or path has too few points.")
                return
            }
            
            let firstCoord = path.coordinate(at: 0)
            
            let camera = GMSCameraPosition.camera(
                withLatitude: firstCoord.latitude,
                longitude: firstCoord.longitude,
                zoom: zoom
            )
            
                // Smoothly animate to this coordinate
            mapView.animate(to: camera)
            print("🎯 Centered on first polyline coordinate: \(firstCoord.latitude), \(firstCoord.longitude)")
        }

            // MARK: - Route overlays

        func clearRouteOverlays(on mapView: GMSMapView) {
            guard activePolyline != nil || !lastProcessedPolyline.isEmpty else { return }

            activePolyline?.map = nil
            activePolyline = nil
            traveledPolyline?.map = nil
            traveledPolyline = nil
            lastProcessedPolyline = ""
        }

        func resolvedDriverCoordinate(fallback: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
            if let lastDriverCoordinate {
                return lastDriverCoordinate
            }
            let location = parent.driverLocation.driverLocation
            if let lat = coordinateFromChannelValue(location["lat"]),
               let lng = coordinateFromChannelValue(location["lng"]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
            return fallback
        }

        func updateActivePolyline(path: GMSMutablePath, on mapView: GMSMapView) {
            if let existing = activePolyline {
                existing.path = path
                return
            }

            let line = GMSPolyline(path: path)
            line.strokeWidth = 5.0
            line.strokeColor = UIColor(red: 74 / 255, green: 171 / 255, blue: 36 / 255, alpha: 1)
            line.geodesic = true
            line.map = mapView
            activePolyline = line
        }

        func placeRouteMarkersIfNeeded(path: GMSPath, on mapView: GMSMapView) {
            // Prefer the drawn route endpoint so the pin sits on the polyline end.
            if path.count() > 0 {
                addDropOffMarker(at: path.coordinate(at: path.count() - 1), on: mapView)
            } else if let dropoff = TripDropoffController.shared.coordinate {
                addDropOffMarker(
                    at: CLLocationCoordinate2D(latitude: dropoff.lat, longitude: dropoff.lng),
                    on: mapView
                )
            }
            redrawStopMarkers(on: mapView)
        }

        private let minDenseRoutePoints: UInt = 4
        private let sparsePolylineMaxPoints: UInt = 3

        func applyDriverRoute(
            encoded: String,
            on mapView: GMSMapView,
            fitCamera: Bool,
            force: Bool = false
        ) {
            guard !encoded.isEmpty else { return }
            if !force, encoded == lastProcessedPolyline, activePolyline != nil {
                maybeAutoFitCameraToFullPolylineOnce(on: mapView)
                return
            }
            guard let path = gmsPath(fromEncodedPolyline: encoded), path.count() > 1 else {
                print("❌ Failed to decode polyline or path has too few points.")
                return
            }

            if !force,
               let existing = sourceRoutePath,
               existing.count() >= minDenseRoutePoints,
               path.count() <= sparsePolylineMaxPoints,
               path.count() < existing.count() {
                print(
                    "Skipping sparse polyline replace (\(path.count()) pts); " +
                        "keeping denser route (\(existing.count()) pts)"
                )
                trimCompletedPolylineBehindDriver()
                return
            }

            let driverStart = resolvedDriverCoordinate(fallback: path.coordinate(at: 0))
            guard let displayPath = routePathForDisplay(from: path, driver: driverStart) else {
                print("❌ Display path has too few points.")
                return
            }

            lastProcessedPolyline = encoded
            sourceRoutePath = path
            updateActivePolyline(path: displayPath, on: mapView)
            placeRouteMarkersIfNeeded(path: displayPath, on: mapView)
            maybeAutoFitCameraToFullPolylineOnce(on: mapView)

            print("✅ Driver-anchored route applied")
        }

        /// One-time full-route camera fit when a polyline first appears (app open / restore).
        func maybeAutoFitCameraToFullPolylineOnce(on mapView: GMSMapView) {
            guard !userHasInteractedWithMap, !hasFittedCameraToRoute else { return }
            guard sourceRoutePath != nil || activePolyline != nil else { return }

            parent.performRecenter(on: mapView, coordinator: self, fit: "fullPolyline")
            hasFittedCameraToRoute = true
            print("🎯 One-time auto-fit to full polyline")
        }

        /// Same camera behavior as tapping recenter during an active trip.
        func autoFitFullPolylineOnForeground() {
            guard let mapView else { return }
            guard sourceRoutePath != nil || activePolyline != nil else { return }
            performRecenterRequest(fit: "fullPolyline")
        }

        func drawRoute(encoded: String, on mapView: GMSMapView) {
            applyDriverRoute(
                encoded: encoded,
                on: mapView,
                fitCamera: false
            )
        }
    }
    
        // MARK: - UIViewRepresentable Methods
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> GMSMapView {
        // 🔍 Debug: Check what data we have
            print("🔍 makeUIView called")
            print("🔍 Full polyline dictionary: \(polylineController.polyline)")
            print("🔍 Polyline string exists: \(polylineController.polyline["polyline"] != nil)")
            
        let camera = GMSCameraPosition.camera(
            withLatitude: latitude,
            longitude: longitude,
            zoom: zoom
        )
        
        let mapView = GMSMapView(frame: .zero, camera: camera)
        configureMapSettings(mapView)
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        context.coordinator.bindCarMarkers(on: mapView)
        RideMapRecenterRegistry.shared.bind(coordinator: context.coordinator)
        
        if let encoded = polylineController.polyline["polyline"] as? String,
           !encoded.isEmpty {
            context.coordinator.applyDriverRoute(
                encoded: encoded,
                on: mapView,
                fitCamera: false
            )
        }

        let savedDriver = driverLocation.driverLocation
        if !savedDriver.isEmpty {
            context.coordinator.restorePersistedDriverFix(from: savedDriver)
        } else {
            context.coordinator.replayPendingDriverFixIfNeeded()
        }

        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.mapView = uiView
        context.coordinator.bindCarMarkers(on: uiView)
        RideMapRecenterRegistry.shared.bind(coordinator: context.coordinator)
        context.coordinator.replayPendingDriverFixIfNeeded()
    }

    func performRecenter(
        on mapView: GMSMapView,
        coordinator: Coordinator,
        fit: String?
    ) {
        let encoded = polylineController.polyline["polyline"] as? String
        let handled = RideMapRecenterLogic.perform(
            on: mapView,
            fit: fit,
            context: RideMapRecenterLogic.Context(
                polylineEncoded: encoded,
                displayedPolylineCoordinates: coordinator.displayedPolylineCoordinates,
                driverLocation: driverLocation.driverLocation,
                carMarker: coordinator.carMarker,
                dropOffMarker: coordinator.dropOffMarker,
                defaultZoom: zoom
            )
        )

        if handled { return }

        if let location = locationManager.location {
            let camera = GMSCameraPosition.camera(
                withLatitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                zoom: zoom
            )
            mapView.animate(to: camera)
            print("📍 Recentered to current location (no polyline)")
        }
    }

    private func configureMapSettings(_ mapView: GMSMapView) {
        mapView.isUserInteractionEnabled = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.tiltGestures = true
        mapView.settings.rotateGestures = true
        MapChromePolicy.apply(to: mapView)
    }
}

extension RideMapViewRepresentable.Coordinator: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
        if gesture {
            userHasInteractedWithMap = true
        }
    }

    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        true
    }

    func mapView(
        _ mapView: GMSMapView,
        didTapPOIWithPlaceID placeID: String,
        name: String,
        location: CLLocationCoordinate2D
    ) -> Bool {
        true
    }
}

    // MARK: - UIImage Extension for Resizing

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
