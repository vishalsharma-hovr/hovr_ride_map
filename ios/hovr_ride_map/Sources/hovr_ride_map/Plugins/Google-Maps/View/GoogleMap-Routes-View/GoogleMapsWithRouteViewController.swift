//
//  GoogleMapsViewController.swift
//  HOVR
//
//  Created by Vishal Sharma on 30/09/24.
//

import CoreLocation
import Foundation
import Flutter
import GoogleMaps
import SwiftUI
import Combine

struct GoogleMapsWithRouteViewController: UIViewRepresentable {
    var zoom: Float
    var destinationLocation: CLLocationCoordinate2D?
    var snappedCoordinates: [CLLocationCoordinate2D]?
    var flutterResult: FlutterResult?
    var originLocation: CLLocationCoordinate2D?
    var startLocationAddress: String?
    var dropOffLocationAddress: String?
    @ObservedObject var controller: RecenterMapController
    @State var durationText: String?
    @State var startAddress: String?
    @State var endAddress: String?
    @State var startPoint: LatLng?
    @State var endPoint: LatLng?
    @State var routeFetcher :[String:Any]
    
    @State private var updateTimer: Timer?
    @State private var travelDurationSeconds: Int = 0
    @State private var etaSubscriber: AnyCancellable?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator {
        var hasDrawnRoute = false
        var parent: GoogleMapsWithRouteViewController
        weak var mapView: GMSMapView?
        private var recenterCancellable: AnyCancellable?

        init(parent: GoogleMapsWithRouteViewController) {
            self.parent = parent
        }

        func bindRecenterObserver(for controller: RecenterMapController) {
            recenterCancellable?.cancel()
            recenterCancellable = controller.$shouldRecenter
                .receive(on: DispatchQueue.main)
                .sink { [weak self] shouldRecenter in
                    guard shouldRecenter,
                          let self,
                          let mapView = self.mapView,
                          let origin = self.parent.originLocation,
                          let destination = self.parent.destinationLocation else { return }

                    self.parent.updateCameraPosition(
                        mapView: mapView,
                        origin: origin,
                        destination: destination
                    )
                    controller.shouldRecenter = false
                }
        }
    }

    func makeUIView(context: Context) -> GMSMapView {
        guard let origin = originLocation else {
            return GMSMapView()
        }
        let camera = GMSCameraPosition.camera(withLatitude: origin.latitude, longitude: origin.longitude, zoom: zoom)
        let mapView = GMSMapView.map(withFrame: CGRect.zero, camera: camera)
        // Enable zoom, scroll, and other gesture settings
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.rotateGestures = true
//        mapView.settings.myLocationButton = true
        // Load custom map style
        do {
            if let styleURL = HovrRideMapResources.url(forResource: "hovr_map_style", withExtension: "json") {
                mapView.mapStyle = try
                    GMSMapStyle(contentsOfFileURL: styleURL)
            } else {
                print("Unable to find \("hovr_map_style").json")
            }
        } catch {
            print("Error loading map style: \(error)")
        }
        context.coordinator.mapView = mapView
        context.coordinator.parent = self
        context.coordinator.bindRecenterObserver(for: controller)
        return mapView
    }

    private func recenterRoute(on mapView: GMSMapView) {
        guard let start = startPoint, let end = endPoint else {
            return
        }
        
        let bounds = GMSCoordinateBounds(
            coordinate: CLLocationCoordinate2D(
                latitude: originLocation!.latitude,
                longitude: originLocation!.longitude
            ),
            coordinate: CLLocationCoordinate2D(latitude: end.latitude, longitude: end.longitude)
        )
        let update = GMSCameraUpdate.fit(bounds, withPadding: 60)
        mapView.animate(with: update)
        
    }

        // Add these functions inside your struct
    private func startDurationTimer() {
        updateTimer?.invalidate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let currentTime = Date()
            let arrivalTime = currentTime.addingTimeInterval(TimeInterval(travelDurationSeconds))
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "hh:mm a"
            dateFormatter.locale = Locale.current
            
            let formattedTime = dateFormatter.string(from: arrivalTime)
            
            DispatchQueue.main.async {
                self.durationText = formattedTime
            }
        }
    }
    
    private func stopDurationTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }


    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.mapView = mapView
        context.coordinator.parent = self

        guard !context.coordinator.hasDrawnRoute else { return }
        context.coordinator.hasDrawnRoute = true

        if let startPoint = startPoint {
            let gmsMarker = GMSMarker()
            gmsMarker.position = CLLocationCoordinate2D(
                latitude: startPoint.latitude,
                longitude: startPoint.longitude
            )
            let customMarkerView = UIHostingController(rootView: Circle()
                .fill(HovrMapColors.routeGreenLightSwiftUI)
                .frame(width: 15, height: 15)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 2))
            customMarkerView.view.backgroundColor = .clear
            customMarkerView.view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            gmsMarker.iconView = customMarkerView.view
            gmsMarker.map = mapView
        }

        if let destinationLocation = destinationLocation, let origin = originLocation {
            drawRoute(from: origin, to: destinationLocation, on: mapView)
        }
    }

    func calculateBearing(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = origin.latitude.toRadians()
        let lon1 = origin.longitude.toRadians()
        let lat2 = destination.latitude.toRadians()
        let lon2 = destination.longitude.toRadians()

        let deltaLon = lon2 - lon1
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let initialBearing = atan2(y, x)

        // Convert radians to degrees and normalize to 0-360°
        var bearing = initialBearing.toDegrees()
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        return bearing
    }

    func updateCameraPosition(mapView: GMSMapView, origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
        let originCL = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationCL = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distanceInMeters = originCL.distance(from: destinationCL)

        print("📏 Distance between origin and destination: \(distanceInMeters) meters")

        let bearing = calculateBearing(from: origin, to: destination)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            var bounds = GMSCoordinateBounds()
            bounds = bounds.includingCoordinate(origin)
            bounds = bounds.includingCoordinate(destination)

            let cameraUpdate = GMSCameraUpdate.fit(bounds, withPadding: 120)
            mapView.animate(with: cameraUpdate)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let center = CLLocationCoordinate2D(
                    latitude: (origin.latitude + destination.latitude) / 2,
                    longitude: (origin.longitude + destination.longitude) / 2
                )

                let zoomLevel: Float = distanceInMeters < 100 ? 18.5 : mapView.camera.zoom

                let updatedCamera = GMSCameraPosition.camera(
                    withTarget: center,
                    zoom: zoomLevel,
                    bearing: bearing,
                    viewingAngle: 45
                )
                mapView.animate(to: updatedCamera)
            }
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Validate coordinates before reverse geocoding
        guard coordinate.latitude != 0.0, coordinate.longitude != 0.0 else {
            print("❌ Invalid coordinates: \(coordinate.latitude), \(coordinate.longitude)")
            completion("")
            return
        }

        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("❌ Reverse geocode failed: \(error.localizedDescription) (lat: \(coordinate.latitude), lng: \(coordinate.longitude))")
                completion("")
                return
            }

            guard let placemark = placemarks?.first else {
                print("⚠️ No placemark found for location.")
                completion("")
                return
            }

            let addressParts = [
                placemark.name,
                placemark.subLocality,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country,
            ]
            .compactMap { $0 }
            .joined(separator: ", ")

            print("📫 Reverse geocoded address: \(addressParts)")
            completion(addressParts)
        }
    }
    
    private func drawRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, on mapView: GMSMapView) {
        // print("🔍 routeFetcher raw value:", routeFetcher)
        // print("🧩 Type of routeFetcher:", type(of: routeFetcher))
        
        guard let v = routeFetcher as? [String: Any] else {
            print("❌ routeFetcher is not a dictionary")
            return
        }
        
            // MARK: - Safely handle NSNumber / Int / Double values
        func getIntValue(_ value: Any?) -> Int? {
            if let intValue = value as? Int { return intValue }
            if let doubleValue = value as? Double { return Int(doubleValue) }
            if let numberValue = value as? NSNumber { return numberValue.intValue }
            if let strValue = value as? String, let intFromString = Int(strValue) { return intFromString }
            return nil
        }
        
        guard
            let duration = getIntValue(v["durationSeconds"]),
            let distance = getIntValue(v["distanceMeters"]),
            let polyline = v["polyline"] as? String
        else {
            print("❌ Failed to parse routeFetcher data — missing keys or invalid types. Parsed keys: \(v.keys)")
            return
        }
        
        let provider = v["provider"] as? String ?? "Unknown"
        
        print("""
    ✅ Route Parsed Successfully:
    → Provider: \(provider)
    → Distance: \(distance) meters
    → Duration: \(duration) seconds
    → Polyline: \(polyline.prefix(40))...
    """)
        
            // MARK: - Decode polyline and draw route
        guard let path = GMSPath(fromEncodedPath: polyline) else {
            print("❌ Failed to decode polyline string")
            return
        }
        
        DispatchQueue.main.async {
            let routePolyline = GMSPolyline(path: path)
            routePolyline.strokeWidth = 4.0
            routePolyline.strokeColor = UIColor(red: 74/255, green: 171/255, blue: 36/255, alpha: 1)
            routePolyline.map = mapView
        }

        
        
            // MARK: - Save start/end points
        DispatchQueue.main.async {
            self.startPoint = LatLng(latitude: origin.latitude, longitude: origin.longitude)
            self.endPoint = LatLng(latitude: destination.latitude, longitude: destination.longitude)
        }
        
            // MARK: - Adjust camera
        var bounds = GMSCoordinateBounds()
        for i in 0..<path.count() {
            bounds = bounds.includingCoordinate(path.coordinate(at: i))
        }
        let update = GMSCameraUpdate.fit(bounds, withPadding: 80)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            mapView.animate(with: update)
        }
        
            // MARK: - ETA Timer
        self.travelDurationSeconds = duration
        self.updateTimer?.invalidate()
        if duration > 0 {
            let currentTime = Date()
            let arrivalTime = currentTime.addingTimeInterval(TimeInterval(duration))
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            timeFormatter.locale = Locale.current
            
                // Format arrival time and duration text
            let arrivalString = timeFormatter.string(from: arrivalTime)
            
            let minutes = duration / 60
            let hours = minutes / 60
            let readableDuration: String
            
            if hours > 0 {
                readableDuration = "\(hours) hr \(minutes % 60) min"
            } else {
                readableDuration = "\(minutes) min"
            }
            
            let formattedTime = "Arriving by \(arrivalString)"
            
            DispatchQueue.main.async {
                self.durationText = formattedTime
            }
            
            print("🕒 \(formattedTime)")
        }
            // MARK: - Adjust camera
        for i in 0..<path.count() {
            bounds = bounds.includingCoordinate(path.coordinate(at: i))
        }
        
            // Instead of directly calling animate(with:update)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let origin = originLocation, let destination = destinationLocation {
                updateCameraPosition(mapView: mapView, origin: origin, destination: destination)
            }
        }
        
        reverseGeocode(coordinate: origin) { _ in
            DispatchQueue.main.async {
                guard path.count() > 0 else { return }
                let firstCoordinate = path.coordinate(at: 0)
                
                let etaText = ETAController.shared.etaValue.isEmpty ? "1" : ETAController.shared.etaValue
                let startMarkerView = StartPinMarkerView(time: etaText)
                let host = UIHostingController(rootView: startMarkerView)
                host.view.backgroundColor = .clear
                host.view.frame = CGRect(x: 0, y: 0, width: 80, height: 100)
                
                let startMarker = GMSMarker(position: firstCoordinate)
                startMarker.iconView = host.view
                startMarker.groundAnchor = CGPoint(x: 0.5, y: 0.82)
                startMarker.map = mapView
                
                    // 👇 Observe live ETA changes
                etaSubscriber = ETAController.shared.$etaValue
                    .receive(on: RunLoop.main)
                    .sink { newEta in
                        guard !newEta.isEmpty else { return }
                        print("🕒 Updated ETA: \(newEta)")
                        let updatedView = StartPinMarkerView(time: newEta)
                        let updatedHost = UIHostingController(rootView: updatedView)
                        updatedHost.view.backgroundColor = .clear
                        updatedHost.view.frame = host.view.frame
                        startMarker.iconView = updatedHost.view
                    }
            }
        }
        
            // MARK: - Destination Marker
        reverseGeocode(coordinate: destination) { placeName in
            DispatchQueue.main.async {
                    // ✅ Get the actual end coordinate from the decoded polyline
                guard let lastCoordinate = path.count() > 0 ? path.coordinate(at: path.count() - 1) : nil else {
                    print("⚠️ No coordinates found in path for destination marker.")
                    return
                }
                
                let markerTime = self.durationText ?? ""
                let markerAddress = placeName
                let markerView = MarkerView(
                    time: markerTime,
                    address: self.dropOffLocationAddress ?? markerAddress
                )
                let host = UIHostingController(rootView: markerView)
                host.view.backgroundColor = .clear
                host.view.frame = CGRect(x: 0, y: 0, width: 240, height: 40)
                
                    // ✅ Place the marker on the actual last coordinate of the polyline
                let marker = GMSMarker(position: lastCoordinate)
                marker.iconView = host.view
                marker.groundAnchor = CGPoint(x: 0.0999, y: 0.53)
                marker.map = mapView
                
                print("📍 Destination marker set at polyline end: \(lastCoordinate.latitude), \(lastCoordinate.longitude)")
            }
        }
       
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.recenterRoute(on: mapView)
            
        }
             
    }

    func drawRoute(on mapView: GMSMapView, with encodedPolyline: String) {
        if let path = GMSPath(fromEncodedPath: encodedPolyline) {
            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = 3.0
            polyline.strokeColor = HovrMapColors.routeGreen
            polyline.map = mapView
        }
    }
}

#Preview {
    MarkerView(time: "12 mins", address: "123 address")
}

struct MarkerView: View {
    var time: String
    var address: String
    @State var width: CGFloat = UIScreen.screenWidth / 2
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 100, height: 30)
                .clipShape(RoundedCorner(radius: 50, corners: [.topLeft, .bottomLeft]))
                .foregroundColor(HovrMapColors.routeGreenMutedSwiftUI)
                .overlay {
                    HStack {
                        Circle()
                            .fill(HovrMapColors.routeGreenLightSwiftUI)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Circle()
                                    .fill(Color(red: 74, green: 171, blue: 36))
                                    .frame(width: 12, height: 12)
                            }
                        
                        Text(time)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            
            Spacer()
            Text(address)
                .font(.system(size: 12))
                .foregroundColor(.black)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.black)
                .padding(.horizontal, 10)
        }
        .frame(width: width, height: 30)
        .background(Color.white)
        .cornerRadius(50)
            // **FIX: Make the entire area tappable**
        .contentShape(Rectangle())
        .onTapGesture {
            print(">>>>>>>>>>>> ONTAP ")
            withAnimation(.easeInOut(duration: 0.3)) {
                if width == UIScreen.screenWidth / 2 {
                    self.width = UIScreen.screenWidth - 20
                } else {
                    self.width = UIScreen.screenWidth / 2
                }
            }
        }
    }
}

extension Double {
    func toRadians() -> Double { self * .pi / 180 }
    func toDegrees() -> Double { self * 180 / .pi }
}


