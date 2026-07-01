//
//  HomeViewGoogleMapFactory.swift
//  HOVR
//
//  Created by Bipan Sharma on 02/10/25.
//

import Foundation
import Flutter
import UIKit

//final class HomeViewGoogleMapFactory: NSObject, FlutterPlatformViewFactory {
//    private let messenger: FlutterBinaryMessenger
//
//    init(messenger: FlutterBinaryMessenger) {
//        self.messenger = messenger
//        super.init()
//    }
//
//    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
//        FlutterStandardMessageCodec.sharedInstance()
//    }
//
////    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
////        HomeViewGoogleMapIOS(frame: frame, viewId: viewId, messenger: messenger)
////    }
//    
//    func create(withFrame frame: CGRect,
//                    viewIdentifier viewId: Int64,
//                    arguments args: Any?) -> FlutterPlatformView {
//            return HomeViewGoogleMapPlatformView(
//                frame: frame,
//                viewIdentifier: viewId,
//                arguments: args,
//                binaryMessenger: messenger
//            )
//        }
//}


final class HomeViewGoogleMapFactory: NSObject, FlutterPlatformViewFactory {
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
        HomeViewGoogleMapIOS(frame: frame, messenger: messenger, viewId: viewId)
    }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
