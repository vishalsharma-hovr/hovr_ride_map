//
//  ShowNearByDriverPlugin.swift
//  hovr_ride_map
//

import Flutter

final class ShowNearByDriverPlugin: NSObject, FlutterPlugin {
    static let controller = ShowNearByDriverController.shared
    private static let shared = ShowNearByDriverPlugin()

    static func install(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "show-drivers-location-on-map",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            shared.handle(call, result: result)
        }
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        install(messenger: registrar.messenger())
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "show-drivers":
            handleShowDrivers(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleShowDrivers(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let drivers = args["nearbyDrivers"] as? [[String: Any]]
        else {
            result(nil)
            return
        }
        Self.controller.updateDriverLocations(drivers: drivers)
        result(nil)
    }
}
