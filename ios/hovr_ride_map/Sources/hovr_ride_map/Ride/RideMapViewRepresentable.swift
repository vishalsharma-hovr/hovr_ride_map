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
        var traveledPolyline: GMSPolyline? // Polyline for the traveled path
        var lastProcessedPolyline: String = ""
        
            // Marker properties
        var carMarker: GMSMarker?
        var dropOffMarker: GMSMarker?
        
        func performRecenterRequest(fit: String?) {
            guard let mapView else {
                NSLog("⚠️ [hovr_ride_map] performRecenterRequest: mapView is nil")
                return
            }
            parent.performRecenter(
                on: mapView,
                coordinator: self,
                fit: fit
            )
        }
        
        init(_ parent: RideMapViewRepresentable) {
            self.parent = parent
            super.init()

            parent.controller.$shouldRecenter
                .receive(on: DispatchQueue.main)
                .sink { [weak self] shouldRecenter in
                    guard shouldRecenter,
                          let self,
                          let mapView = self.mapView else { return }

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
                    return oldPolyline == newPolyline
                }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] dict in
                    guard
                        let self = self,
                        let encoded = dict["polyline"] as? String,
                        !encoded.isEmpty,
                        let mapView = self.mapView,
                        encoded != self.lastProcessedPolyline
                    else {
                        return
                    }
                    self.lastProcessedPolyline = encoded
                    self.drawRoute(encoded: encoded, on: mapView)
                }
                .store(in: &cancellables)

            parent.driverLocation.$driverLocation
                .receive(on: DispatchQueue.main)
                .sink { [weak self] location in
                    guard
                        let self,
                        let lat = location["lat"] as? CLLocationDegrees,
                        let lng = location["lng"] as? CLLocationDegrees
                    else {
                        return
                    }
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    if let car = self.carMarker {
                        CATransaction.begin()
                        CATransaction.setAnimationDuration(1.0)
                        car.position = coordinate
                        CATransaction.commit()
                    }
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
            print("✅ Coordinator deallocated")
        }
        
            // MARK: - Add Marker
        
        func addMarker(at position: CLLocationCoordinate2D, on mapView: GMSMapView, isDriver: Bool = false) -> GMSMarker {
            let marker = GMSMarker(position: position)
            if isDriver, let carImage = HovrRideMapResources.image(named: "car-icon") {
                let scale = zoomScale(for: mapView.camera.zoom)
                marker.icon = carImage.resized(to: CGSize(width: scale, height: scale))
            } else if !isDriver {
                marker.icon = GMSMarker.markerImage(with: .red)
            }
            marker.map = mapView
            return marker
        }
        
        func addDropOffMarker(at position: CLLocationCoordinate2D, on mapView: GMSMapView) {
            dropOffMarker?.map = nil
            
            let marker = GMSMarker(position: position)
            if let dropImage = HovrRideMapResources.image(named: "drop-off-marker") {
                marker.icon = dropImage.resized(to: CGSize(width: 30, height: 30))
            } else {
                marker.icon = GMSMarker.markerImage(with: .blue)
            }
            marker.map = mapView
            self.dropOffMarker = marker
        }
        
            // MARK: - Zoom Scale Calculation
        
        func zoomScale(for zoom: Float) -> CGFloat {
            let minSize: CGFloat = 30
            let maxSize: CGFloat = 60
            let minZoom: Float = 10
            let maxZoom: Float = 20
            
            let clampedZoom = max(minZoom, min(maxZoom, zoom))
            let normalizedZoom = (clampedZoom - minZoom) / (maxZoom - minZoom)
            return minSize + (maxSize - minSize) * CGFloat(normalizedZoom)
        }
        
            // MARK: - Place or Animate Car Marker
        
        func placeOrAnimateCarMarker(at coordinate: CLLocationCoordinate2D, bearing: CLLocationDirection, on mapView: GMSMapView) {
            if let existingMarker = carMarker {
                CATransaction.begin()
                CATransaction.setAnimationDuration(1.0)
                existingMarker.position = coordinate
                existingMarker.rotation = bearing
                CATransaction.commit()
                
                print("🚗 Car marker animated to: \(coordinate.latitude), \(coordinate.longitude) with bearing: \(bearing)°")
            } else {
//                let location = DriverLocationController.shared.driverLocation
                var initialPos = coordinate
//                
//                if let lat = location["lat"] as? CLLocationDegrees,
//                   let lng = location["lng"] as? CLLocationDegrees {
//                    initialPos = CLLocationCoordinate2D(latitude: lat, longitude: lng)
//                }
                
                let newMarker = addMarker(
//                    at: initialPos,
                    at: coordinate,
                    on: mapView,
                    isDriver: true
                )
                newMarker.rotation = bearing
                newMarker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                self.carMarker = newMarker
                
                print("🚗 Car marker created at: \(initialPos.latitude), \(initialPos.longitude), with initial bearing: \(bearing)°")
            }
        }
        
            // MARK: - Calculate Bearing
        
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

            // MARK: - Draw Route
        
        func drawRoute(encoded: String, on mapView: GMSMapView) {
            guard !encoded.isEmpty else { return }

            guard let path = gmsPath(fromEncodedPolyline: encoded), path.count() > 1 else {
                print("❌ Failed to decode polyline or path has too few points.")
                return
            }
            
            let firstCoord = path.coordinate(at: 0)
            let secondCoord = path.coordinate(at: 1)
            
            guard CLLocationCoordinate2DIsValid(firstCoord) else {
                print("❌ Invalid start coordinate.")
                return
            }
            
                // Clear previous polylines
            activePolyline?.map = nil
            traveledPolyline?.map = nil
            
                // Draw the upcoming route
            let upcomingRoutePolyline = GMSPolyline(path: path)
            upcomingRoutePolyline.strokeWidth = 5.0
            upcomingRoutePolyline.strokeColor = UIColor(red: 74/255, green: 171/255, blue: 36/255, alpha: 1)
            upcomingRoutePolyline.geodesic = true
            upcomingRoutePolyline.map = mapView
            activePolyline = upcomingRoutePolyline
            
            let currentBearing = calculateBearing(from: firstCoord, to: secondCoord)
//            let isFirstDraw = (carMarker == nil)
//            
//            let location = DriverLocationController.shared.driverLocation
//            var driverPos: CLLocationCoordinate2D?
//            if let lat = location["lat"] as? CLLocationDegrees,
//               let lng = location["lng"] as? CLLocationDegrees {
//                driverPos = CLLocationCoordinate2D(latitude: lat, longitude: lng)
//            }
            
//            if !CLLocationCoordinate2DIsValid(firstCoord) {
//                if let driverPos = driverPos {
//                    placeOrAnimateCarMarker(at: driverPos, bearing: currentBearing, on: mapView)
//                }
//            } else {
//                placeOrAnimateCarMarker(at: firstCoord, bearing: currentBearing, on: mapView)
//            }
            
            // Prefer live driver location for the cab icon when available.
            if let lat = parent.driverLocation.driverLocation["lat"] as? CLLocationDegrees,
               let lng = parent.driverLocation.driverLocation["lng"] as? CLLocationDegrees {
                placeOrAnimateCarMarker(
                    at: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    bearing: currentBearing,
                    on: mapView
                )
            } else {
                placeOrAnimateCarMarker(at: firstCoord, bearing: currentBearing, on: mapView)
            }
            
            if let lastCoordinate = path.count() > 0 ? path.coordinate(at: path.count() - 1) : nil {
                addDropOffMarker(at: lastCoordinate, on: mapView)
                print("📍 Drop-off marker placed at: \(lastCoordinate.latitude), \(lastCoordinate.longitude)")
            }
            
            if carMarker == nil {
                let bounds = GMSCoordinateBounds(path: path)
                let update = GMSCameraUpdate.fit(bounds, withPadding: 100)
                mapView.moveCamera(update)
            }
            print("✅ Route drawn successfully")
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
        context.coordinator.mapView = mapView
        RideMapRecenterRegistry.shared.bind(coordinator: context.coordinator)
        
        // ✅ Always draw the route if polyline data exists
            if let encoded = polylineController.polyline["polyline"] as? String,
               !encoded.isEmpty {
                print("polyline-data: \(encoded)")
                // Reset lastProcessedPolyline to ensure it draws
                context.coordinator.lastProcessedPolyline = encoded
                context.coordinator.drawRoute(encoded: encoded, on: mapView)
            }
        
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.mapView = uiView
        RideMapRecenterRegistry.shared.bind(coordinator: context.coordinator)
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
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.tiltGestures = true
        mapView.settings.rotateGestures = true
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
