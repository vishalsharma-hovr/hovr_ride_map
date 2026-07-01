    //
    //  GoogleMapsView.swift
    //  HOVR
    //
    //  Created by Vishal Sharma on 06/12/24.
    //

import SwiftUI
import CoreLocation
import UIKit
import Flutter
import GoogleMaps


struct GoogleMaps: View {
    var result: FlutterResult?
    var flutterMethod: FlutterMethodCall?
    @StateObject private var locationManager = LocationManager()
    @State private var zoomLevel: Float = 16.5
    
    var body: some View {
        ZStack {
            if let location = locationManager.location {
                GoogleMapsViewRepresentable(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    zoom: zoomLevel
                )
            } else {
                VStack {
                    ProgressView()
                }
            }
        }
    }
    
}
