//
//  GoogleMaps-Plugin.swift
//  hovr_ride_map
//

import CoreLocation
import GoogleMaps
import Flutter
import UIKit

class RecenterMapController: ObservableObject {
    static let shared = RecenterMapController()
    @Published var shouldRecenter: Bool = false
    var recenterFit: String?
    private init() {}
}

class TripStageController: ObservableObject {
    static let shared = TripStageController()
    @Published var tripStage: String = ""
    private init() {}
}

class ETAController: ObservableObject {
    static let shared = ETAController()
    @Published var etaValue: String = ""
    private init() {}
}

final class GoogleMapsPlugin: NSObject, RideViewChannelHandler {
    static let instance = GoogleMapsPlugin()
    static var sharedMapController = RecenterMapController.shared
    static var routePolylineController = PolylineController.shared
    static var flutterMethodChannel: FlutterMethodChannel?

    static func install(messenger: FlutterBinaryMessenger) {
        RideViewChannelHub.push(instance)
        flutterMethodChannel = FlutterMethodChannel(
            name: "ride-view-channel",
            binaryMessenger: messenger
        )
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "recenter-map":
            let fit = (call.arguments as? [String: Any])?["fit"] as? String
            DispatchQueue.main.async {
                if RideMapRecenterRegistry.shared.requestRecenter(fit: fit) {
                    return
                }
                let controller = GoogleMapsPlugin.sharedMapController
                controller.shouldRecenter = false
                controller.recenterFit = fit
                controller.shouldRecenter = true
            }
            result(nil)

        case "polylines-channel":
            guard let args = call.arguments as? [String: Any],
                  let polylineString = args["polyline"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing 'polyline'", details: nil))
                return
            }
            let force = args["force"] as? Bool ?? false
            DispatchQueue.main.async {
                if force {
                    GoogleMapsPlugin.routePolylineController.clearPolyline()
                }
                GoogleMapsPlugin.routePolylineController.polyline = ["polyline": polylineString]
            }
            result(nil)

        case "clear-route":
            DispatchQueue.main.async {
                GoogleMapsPlugin.routePolylineController.clearPolyline()
            }
            result(nil)

        case "eta-channel":
            guard let args = call.arguments as? [String: Any],
                  let seconds = args["eta"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing eta seconds", details: nil))
                return
            }
            DispatchQueue.main.async {
                ETAController.shared.etaValue = "\(seconds)"
            }
            result(nil)

        case "trip-stage":
            guard let args = call.arguments as? [String: Any],
                  let stage = args["tripStage"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing tripStage", details: nil))
                return
            }
            DispatchQueue.main.async {
                if TripStageController.shared.tripStage != stage {
                    TripStageController.shared.tripStage = stage
                }
                if stage == "headingToDestination" {
                    TripPickupController.shared.clear()
                    TripUserController.shared.clear()
                }
            }
            result(nil)

        case "clear-pickup-user-markers":
            DispatchQueue.main.async {
                TripPickupController.shared.clear()
                TripUserController.shared.clear()
            }
            result(nil)

        case "pickup-location":
            guard let args = call.arguments as? [String: Any],
                  let lat = args["lat"] as? Double,
                  let lng = args["lng"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing pickup lat/lng", details: nil))
                return
            }
            DispatchQueue.main.async {
                TripPickupController.shared.update(lat: lat, lng: lng)
            }
            result(nil)

        case "user-location":
            guard let args = call.arguments as? [String: Any],
                  let lat = args["lat"] as? Double,
                  let lng = args["lng"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing user lat/lng", details: nil))
                return
            }
            DispatchQueue.main.async {
                TripUserController.shared.update(lat: lat, lng: lng)
            }
            result(nil)

        case "driver-location-update":
            result(nil)

        case "drop-off-location":
            guard let args = call.arguments as? [String: Any],
                  let lat = args["lat"] as? Double,
                  let lng = args["lng"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing dropoff lat/lng", details: nil))
                return
            }
            DispatchQueue.main.async {
                TripDropoffController.shared.update(lat: lat, lng: lng)
            }
            result(nil)

        case "trip-stops":
            guard let args = call.arguments as? [String: Any],
                  let stops = args["stops"] as? [[String: Any]] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing stops list", details: nil))
                return
            }
            DispatchQueue.main.async {
                TripStopsController.shared.update(rawStops: stops)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
