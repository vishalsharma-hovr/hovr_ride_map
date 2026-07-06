//
//  GoogleMapsWithRoute.swift
//  HOVR
//
//  Created by Vishal Sharma on 23/10/24.
//

import CoreLocation
import Foundation
import SwiftUI
import UIKit
import Flutter

struct RouteStopLocation {
    let coordinate: CLLocationCoordinate2D
    let address: String
    let index: Int

    static func parse(from args: Any?) -> [RouteStopLocation] {
        guard let argsDict = args as? [String: Any],
              let stopsAny = argsDict["stops"] as? [Any]
        else {
            return []
        }
        return parseList(stopsAny)
    }

    private static func parseList(_ stopsData: [Any]) -> [RouteStopLocation] {
        var result: [RouteStopLocation] = []
        for item in stopsData {
            guard let stopMap = item as? [String: Any] else { continue }
            guard let latitude = doubleValue(stopMap["latitude"]),
                  let longitude = doubleValue(stopMap["longitude"])
            else {
                continue
            }
            if latitude == 0, longitude == 0 { continue }
            let address = stopMap["address"] as? String ?? ""
            result.append(
                RouteStopLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    address: address,
                    index: result.count + 1
                )
            )
        }
        return result
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        return nil
    }
}

struct RouteAddressTagMarkerView: View {
    let tagLabel: String
    let address: String
    @State private var isExpanded = false

    private var markerWidth: CGFloat {
        isExpanded ? UIScreen.screenWidth - 20 : UIScreen.screenWidth / 2
    }

    private var markerHeight: CGFloat {
        isExpanded ? 48 : 30
    }

    private var addressLineLimit: Int {
        isExpanded ? 2 : 1
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Rectangle()
                .frame(width: 100, height: 30)
                .clipShape(RoundedCorner(radius: 50, corners: [.topLeft, .bottomLeft]))
                .foregroundColor(HovrMapColors.routeGreenMutedSwiftUI)
                .overlay {
                    HStack {
                        Circle()
                            .fill(HovrMapColors.routeGreenLightSwiftUI)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Circle()
                                    .fill(Color(red: 74, green: 171, blue: 36))
                                    .frame(width: 12, height: 12)
                            }

                        Text(tagLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }

            Text(address)
                .font(.system(size: 12))
                .foregroundColor(.black)
                .lineLimit(addressLineLimit)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .foregroundColor(.black)
                .padding(.horizontal, 10)
        }
        .frame(width: markerWidth, height: markerHeight, alignment: .leading)
        .background(Color.white)
        .cornerRadius(50)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        }
    }
}

struct StopPinMarkerView: View {
    let stopNumber: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
            Circle()
                .stroke(Color(red: 74 / 255, green: 171 / 255, blue: 36 / 255), lineWidth: 2.5)
                .frame(width: 28, height: 28)
            Text("\(stopNumber)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
        }
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

struct StopTaggedMarkerView: View {
    var stopLabel: String
    var address: String

    var body: some View {
        RouteAddressTagMarkerView(tagLabel: stopLabel, address: address)
    }
}

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
    var stops: [RouteStopLocation] = []

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
                    routeFetcher: routeData,
                    stops: stops
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


