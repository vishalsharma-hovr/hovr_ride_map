//
//  HomeViewGooglePlatformView.swift
//  hovr_ride_map
//

import Flutter
import UIKit

final class HomeViewGoogleMapPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
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
            HomeViewGoogleMapPlatformView(
                frame: frame,
                viewIdentifier: viewId,
                arguments: args,
                binaryMessenger: messenger
            )
        }
    }
}
