//
//  GoogleMapViewPlatformView.swift
//  hovr_ride_map
//

import Flutter
import UIKit

final class HomeViewGoogleMapPlatformView: NSObject, FlutterPlatformView {
    private let inner: HomeViewGoogleMapIOS

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        let argsMap = args as? [String: Any]
        inner = HomeViewGoogleMapIOS(
            frame: frame,
            messenger: messenger!,
            viewId: viewId,
            initialLatitude: argsMap?["initialLatitude"] as? Double,
            initialLongitude: argsMap?["initialLongitude"] as? Double
        )
        super.init()
    }

    func view() -> UIView {
        inner.view()
    }
}
