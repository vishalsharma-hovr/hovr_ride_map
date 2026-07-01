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
        inner = HomeViewGoogleMapIOS(frame: frame, messenger: messenger!, viewId: viewId)
        super.init()
    }

    func view() -> UIView {
        inner.view()
    }
}
