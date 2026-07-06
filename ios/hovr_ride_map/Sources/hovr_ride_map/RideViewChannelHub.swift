import Flutter

/// Single permanent handler for `ride-view-channel`.
///
/// Platform map views push/pop delegates so disposing one view never leaves the
/// channel without a handler.
final class RideViewChannelHub {
    private static let lock = NSLock()
    private static var handlers: [RideViewChannelHandler] = []
    private static var installed = false

    static let noopMethods: Set<String> = [
        "recenter-map",
        "driver-location-update",
        "polylines-channel",
        "clear-route",
        "eta-channel",
        "trip-stage",
        "pickup-location",
        "user-location",
        "drop-off-location",
        "trip-stops",
        "clear-pickup-user-markers",
    ]

    static func install(messenger: FlutterBinaryMessenger) {
        lock.lock()
        defer { lock.unlock() }
        guard !installed else { return }

        let channel = FlutterMethodChannel(name: "ride-view-channel", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            lock.lock()
            let handler = handlers.last
            lock.unlock()

            if let handler {
                handler.handle(call, result: result)
            } else if noopMethods.contains(call.method) {
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        installed = true
    }

    static func push(_ handler: RideViewChannelHandler) {
        lock.lock()
        handlers.append(handler)
        lock.unlock()
    }

    static func pop(_ handler: RideViewChannelHandler) {
        lock.lock()
        handlers.removeAll { $0 === handler }
        lock.unlock()
    }
}

protocol RideViewChannelHandler: AnyObject {
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)
}
