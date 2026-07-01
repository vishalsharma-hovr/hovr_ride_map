import Flutter
import SwiftUI
import UIKit

/// Active ride-map handler — pushed on top of [GoogleMapsPlugin] while the ride platform view lives.
private final class RideMapRideChannelHandler: NSObject, RideViewChannelHandler {
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "recenter-map":
            let fit = (call.arguments as? [String: Any])?["fit"] as? String
            DispatchQueue.main.async {
                RideMapRecenterRegistry.shared.requestRecenter(fit: fit)
            }
            result(nil)

        default:
            GoogleMapsPlugin.instance.handle(call, result: result)
        }
    }
}

/// Unified in-trip map platform view for all [RideMapMode] values.
final class RideMapPlatformView: NSObject, FlutterPlatformView {
    private let hostingController: UIHostingController<RideMapContentView>
    private let channelHandler = RideMapRideChannelHandler()

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        if let argsDict = args as? [String: Any],
           let mode = argsDict["mode"] as? String,
           !mode.isEmpty {
            TripStageController.shared.tripStage = mode
        }

        hostingController = UIHostingController(rootView: RideMapContentView())
        super.init()
        hostingController.view.frame = frame
        RideViewChannelHub.push(channelHandler)
    }

    deinit {
        RideViewChannelHub.pop(channelHandler)
    }

    func view() -> UIView {
        hostingController.view
    }
}

final class RideMapPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        HovrRideMapPlatformViewSupport.create(frame: frame) {
            RideMapPlatformView(
                frame: frame,
                viewIdentifier: viewId,
                arguments: args,
                binaryMessenger: messenger
            )
        }
    }
}
