//
//  GoogleMapsWithRoute.swift
//  HOVR
//
//  Created by Vishal Sharma on 23/10/24.
//

import CoreLocation
import SwiftUI
import UIKit
import Flutter

struct GoogleMapsWithRoute: View {
    var result: FlutterResult?
    var flutterMethod: FlutterMethodCall?
    @State var locationManager = LocationManager()
    @State private var zoomLevel: Float = 15.0
    @State var mapController: RecenterMapController
    var destinationLocation: CLLocationCoordinate2D
    var originLocation: CLLocationCoordinate2D
    var polyline: String
    var duration: String
    var distance: String
    var routeData :[String: Any] = [:]
    var pickUpAddress: String
    var dropOffAddress: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if locationManager.location != nil {
                GoogleMapsWithRouteViewController(
                    zoom: zoomLevel,
                    destinationLocation: destinationLocation,
                    originLocation: originLocation,
                    startLocationAddress: pickUpAddress,
                    dropOffLocationAddress: dropOffAddress,
                    controller: mapController,
                    routeFetcher: routeData
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                VStack {
                    ProgressView()
                }
            }
        }
    }
}


