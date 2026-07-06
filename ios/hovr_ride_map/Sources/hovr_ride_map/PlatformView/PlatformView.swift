//
//  PlatformView.swift
//  hovr_ride_map
//

import CoreLocation
import Flutter
import Foundation
import GoogleMaps
import SwiftUI
import UIKit

// MARK: - RouteOnGoogleMapsView
class RouteOnGoogleMapsView: NSObject, FlutterPlatformView {
    private var hostingController: UIHostingController<GoogleMapsWithRoute>
    private var recenterChannel: FlutterMethodChannel?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        debugPrint(
            "RouteOnGoogleMapsView: ✅ Parsed RouteSnapshot ARGS successfully. \(String(describing: args))"
        )
        let destination: CLLocationCoordinate2D = {
            guard let argsDict = args as? [String: Any] else {
                debugPrint("RouteOnGoogleMapsView: Invalid arguments.")
                return CLLocationCoordinate2D(latitude: 0, longitude: 0)
            }
            
            guard let lat = argsDict["latitude"] as? Double,
                  let lng = argsDict["longitude"] as? Double
                    
            else {
                debugPrint("RouteOnGoogleMapsView: Missing or invalid lat/lng.")
                return CLLocationCoordinate2D(latitude: 0, longitude: 0)
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }()
        let origin: CLLocationCoordinate2D = {
            guard let argsDict = args as? [String: Any] else {
                debugPrint("RouteOnGoogleMapsView: Invalid arguments.")
                return CLLocationCoordinate2D(latitude: 0, longitude: 0)
            }
            
            guard  let originLat = argsDict["pickup-lat"] as? Double,
                   let orginLng = argsDict["pickup-long"] as? Double
                    
            else {
                debugPrint("RouteOnGoogleMapsView: Missing or invalid lat/lng.")
                return CLLocationCoordinate2D(latitude: 0, longitude: 0)
            }
            
            return CLLocationCoordinate2D(latitude: originLat, longitude: orginLng)
        }()
        let routeSnapshot: [String: Any] = {
            guard let argsDict = args as? [String: Any],
                  let jsonString = argsDict["computeRoutesResponseJson"] as? String,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                debugPrint("RouteOnGoogleMapsView: ❌ Invalid or missing computeRoutesResponseJson.")
                return [:]
            }
            debugPrint("RouteOnGoogleMapsView: ✅ Parsed RouteSnapshot JSON successfully. \(json)")
            return json
        }()
        
            // ✅ Extract encoded polyline directly (flat, not nested)
        let encodedPolyline: String = routeSnapshot["polyline"] as? String ?? ""
        let durationSeconds: String = routeSnapshot["durationSeconds"] as? String ?? "0"
        let distanceMeters: String = routeSnapshot["distanceMeters"] as? String ?? "0"
        
        let pickupAddress: String = {
            guard let argsDict = args as? [String: Any],
                  let pickupAddress = argsDict["pickup-location-name"] as? String else {
                return "Unknown"
            }
            return pickupAddress
        }()
        
        let dropOffAddress: String = {
            guard let argsDict = args as? [String: Any],
                  let dropOffAddress = argsDict["dropoff-location-name"] as? String else {
                return "Unknown"
            }
            return dropOffAddress
        }()

        let stops = RouteStopLocation.parse(from: args)
        print("RouteOnGoogleMapsView: Parsed \(stops.count) stops")
        
        if encodedPolyline.isEmpty {
            print("⚠️ No polyline found in response")
        }
        
        if durationSeconds == "0" {
            print("⚠️ No durationSeconds found — using 0")
        }
        
        if distanceMeters == "0" {
            print("⚠️ No distanceMeters found — using 0")
        }
        debugPrint("RouteOnGoogleMapsView: 🗺️ Polyline received from RouteSnapshot. routeSnapshot \(type(of:routeSnapshot))")
            // Use the shared MapController from GoogleMapsPlugin
        let sharedController = GoogleMapsPlugin.sharedMapController
        var updatedSnapshot = routeSnapshot
        
        if let durationValue = durationSeconds as? String, !durationValue.isEmpty {
            updatedSnapshot["durationSeconds"] = durationValue
        } else {
            updatedSnapshot["durationSeconds"] = "0" // default if missing
        }
      
        let googleMapsWithRoute = GoogleMapsWithRoute(
            mapController: sharedController,
            destinationLocation: destination,
            originLocation: origin,
            polyline: encodedPolyline,
            duration: durationSeconds,
            distance: distanceMeters,
            routeData : updatedSnapshot,
            pickUpAddress: pickupAddress,
            dropOffAddress: dropOffAddress,
            stops: stops
        )
        
        print("🔍 RouteOnGoogleMapsView PARAMS:")
        // print("➡️ Origin: \(origin.latitude), \(origin.longitude)")
        // print("➡️ Destination: \(destination.latitude), \(destination.longitude)")
        // print("➡️ Polyline: \(String(describing: encodedPolyline))")
        // print("➡️ DurationSeconds: \(String(describing: durationSeconds))")
        // print("➡️ DistanceMeters: \(String(describing: distanceMeters))")
        print("➡️ Pickup Address: \(String(describing: pickupAddress))")
        print("➡️ Drop Off Address: \(String(describing: dropOffAddress))")
        print("➡️ RouteSnapshot keys: \(routeSnapshot.keys)")
        self.hostingController = UIHostingController(rootView: googleMapsWithRoute)
        super.init()
        hostingController.view.frame = frame

        if let messenger {
            let channel = FlutterMethodChannel(
                name: "routes-on-map-view",
                binaryMessenger: messenger
            )
            channel.setMethodCallHandler { call, result in
                switch call.method {
                case "recenter-map":
                    DispatchQueue.main.async {
                        GoogleMapsPlugin.sharedMapController.shouldRecenter = true
                    }
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
            recenterChannel = channel
        }
    }

    func view() -> UIView {
        return hostingController.view
    }
}
