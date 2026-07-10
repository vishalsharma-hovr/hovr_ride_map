//
//  GlobalFlutterBridge.swift
//  HOVR
//

import Flutter
import Foundation

class GlobalFlutterBridge: NSObject {
    static let shared = GlobalFlutterBridge()

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    override private init() {
        super.init()
    }

    func setupChannels(messenger: FlutterBinaryMessenger) {
        print("🚀 Setting up global Flutter channels")

        methodChannel = FlutterMethodChannel(
            name: "com.hovr/global_channel",
            binaryMessenger: messenger
        )

        eventChannel = FlutterEventChannel(
            name: "com.hovr/global_events",
            binaryMessenger: messenger
        )

        eventChannel?.setStreamHandler(self)
        methodChannel?.setMethodCallHandler(handleMethodCall)
    }

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
        case "eta":
            if let etaValue = call.arguments as? String {
                print("⏱️ [Bridge] ETA received from Flutter: \(etaValue)")
                DispatchQueue.main.async {
                    ETAController.shared.etaValue = etaValue
                }
                result("✅ ETA updated")
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "Expected String ETA", details: nil))
            }
        case "driver-location-channel":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "BAD_ARGS", message: "Expected map", details: nil))
                return
            }
            print("🛰️ [Bridge] Received DRIVER LOCATION data from Flutter: \(args)")
            DispatchQueue.main.async {
                guard let normalized = normalizedDriverLocationDict(from: args) else {
                    print("⚠️ [Bridge] Invalid driver location args: \(args)")
                    return
                }
                DriverLocationController.shared.driverLocation = normalized
            }
            result("ok")
        case "polylines-channel":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "BAD_ARGS", message: "Expected map", details: nil))
                return
            }
            print("🛰️ [Bridge] Received polyline data from Flutter: \(args)")
            let force = args["force"] as? Bool ?? false
            DispatchQueue.main.async {
                if force {
                    PolylineController.shared.clearPolyline()
                }
                PolylineController.shared.polyline = args
            }
            result("ok")
        case "clear-route":
            print("🛰️ [Bridge] Received clear route command from Flutter:")
            DispatchQueue.main.async {
                PolylineController.shared.clearPolyline()
            }
            result("ok")
        case "clear-driver-location":
            DispatchQueue.main.async {
                DriverLocationController.shared.clearDriverLocation()
            }
            result("ok")
        case "clear-pickup-user-markers":
            DispatchQueue.main.async {
                TripPickupController.shared.clear()
                TripUserController.shared.clear()
            }
            result("ok")
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func sendEvent(_ data: [String: Any]) {
        guard let sink = eventSink else {
            print("⚠️ No Flutter event listener connected")
            return
        }
        sink(data)
    }
}

extension GlobalFlutterBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("🎧 Flutter started listening on EventChannel")
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("❌ Flutter stopped listening on EventChannel")
        eventSink = nil
        return nil
    }
}
