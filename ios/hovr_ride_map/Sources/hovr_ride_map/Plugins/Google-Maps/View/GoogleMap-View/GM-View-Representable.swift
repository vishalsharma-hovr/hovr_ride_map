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

// MARK: - GoogleMapsViewRepresentable

struct GoogleMapsViewRepresentable: UIViewRepresentable {
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        
    }

    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let zoom: Float
    
    init(latitude: CLLocationDegrees, longitude: CLLocationDegrees, zoom: Float) {
        self.latitude = latitude
        self.longitude = longitude
        self.zoom = zoom
    }
    
    // MARK: - Coordinator Class
    
    // The Coordinator is a class that acts as a delegate for the UIView (GMSMapView)
    // and holds the mutable state that needs to persist across SwiftUI updates.
    class Coordinator: NSObject {
        var parent: GoogleMapsViewRepresentable
        var mapView: GMSMapView?
    
        init(_ parent: GoogleMapsViewRepresentable) {
            self.parent = parent
        }
        
        // Invalidate the timer when the Coordinator is deallocated
        deinit {
            print("Coordinator deinitialized and timer invalidated.")
        }
             
        func addMarker(at position: CLLocationCoordinate2D, on mapView: GMSMapView, isDriver: Bool = false) -> GMSMarker {
            let marker = GMSMarker(position: position)
            if isDriver, let carImage = HovrRideMapResources.image(named: "car-icon") {
                let scale = zoomScale(for: mapView.camera.zoom)
                marker.icon = carImage.resized(to: CGSize(width: scale, height: scale))
            } else if !isDriver {
                // Default red pin for non-driver markers if needed
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
    }
    
    // MARK: - UIViewRepresentable Protocol Methods
    
    // Creates the Coordinator for this UIViewRepresentable instance
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Creates and configures the GMSMapView
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: latitude, longitude: longitude, zoom: zoom)
        let newMapView = GMSMapView(frame: .zero, camera: camera)
        configureMapSettings(newMapView)      
        context.coordinator.mapView = newMapView
        return newMapView
    }
    
    // Configures general map settings once
    private func configureMapSettings(_ mapView: GMSMapView) {
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = true
        mapView.settings.compassButton = true
    // mapView.isMyLocationEnabled = false
    }
    
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? self
    }
}

// MARK: - Coordinate Distance Helper

extension CLLocationCoordinate2D {
    func distance(from other: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }
}

// MARK: - LocationManager

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var lastGeocodeTime: Date?
    private var lastGeocodedLocation: CLLocation?
    private var isGeocoding = false

    private let minInterval: TimeInterval = 2.0 // seconds
    private let distanceThreshold: CLLocationDistance = 50 // meters

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        updateAuthorizationStatus()
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedWhenInUse,
             .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied,
             .restricted:
            break
        @unknown default:
            break
        }
    }

    private func shouldReverseGeocode(newLocation: CLLocation) -> Bool {
        let now = Date()

        if isGeocoding {
            print("⏱ Already geocoding.")
            return false
        }

        if let lastTime = lastGeocodeTime, now.timeIntervalSince(lastTime) < minInterval {
            print("⏱ Cooldown active.")
            return false
        }

        if let lastLoc = lastGeocodedLocation {
            let distance = newLocation.distance(from: lastLoc)
            if distance < distanceThreshold {
            // print("📏 User has moved only \(Int(distance))m. Skipping geocode.")
                return false
            }
        }
        return true
    }

    private func reverseGeocodeIfNeeded(for location: CLLocation) {
        guard shouldReverseGeocode(newLocation: location) else {
            return
        }
        isGeocoding = true
        lastGeocodeTime = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            location.fetchPlacemark { [weak self] placemark, error in
                guard let self = self else {
                    return
                }
                self.isGeocoding = false
                if let placemark = placemark {
                    self.lastGeocodedLocation = location
                    print("📍 Reverse geocode: \(placemark.name ?? "Unknown"), \(placemark.locality ?? "")")
                } else if let nsError = error as NSError? {
                    if nsError.domain == "GEOErrorDomain" && nsError.code == -3 {
                        print("❌ Apple throttled geocoding. Delaying future attempts.")
                        self.lastGeocodeTime = Date().addingTimeInterval(30)
                    } else if nsError.domain == kCLErrorDomain && nsError.code == 2 {
                        print("⚠️ Location unknown (error 2). Skipping.")
                    } else {
                        print("❌ Reverse geocode error: \(nsError.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorizationStatus()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
       if let loc = location, loc.horizontalAccuracy >= 0 {
            reverseGeocodeIfNeeded(for: loc)
        } else {
            print("⚠️ Location not accurate. Skipping geocode.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed: \(error.localizedDescription)")
    }
}

// MARK: - CLLocation Extension

extension CLLocation {
    func fetchPlacemark(completion: @escaping (_ placemark: CLPlacemark?, _ error: Error?) -> Void) {
        CLGeocoder().reverseGeocodeLocation(self) { placemarks, error in
            completion(placemarks?.first, error)
        }
    }
}

// MARK: - CLAuthorizationStatus Extension

extension CLAuthorizationStatus {
    var isLocationAccessGranted: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }
}
