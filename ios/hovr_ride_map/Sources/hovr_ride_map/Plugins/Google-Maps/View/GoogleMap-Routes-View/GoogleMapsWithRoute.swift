//
//  GoogleMapsWithRoute.swift
//  HOVR
//
//  Created by Vishal Sharma on 23/10/24.
//

import CoreLocation
import Foundation
import GoogleMaps
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
    var isExpanded: Bool = false
    var onTap: (() -> Void)?

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
                                    .fill(MapThemeColors.current.accent.argbColor)
                                    .frame(width: 12, height: 12)
                            }

                        Text(tagLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MapThemeColors.current.onAccent.argbColor)
                            .lineLimit(1)
                    }
                }

            Text(address)
                .font(.system(size: 12))
                .foregroundColor(MapThemeColors.current.onSurface.argbColor)
                .lineLimit(addressLineLimit)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .foregroundColor(MapThemeColors.current.onSurface.argbColor)
                .padding(.horizontal, 10)
        }
        .frame(width: markerWidth, height: markerHeight, alignment: .leading)
        .background(MapThemeColors.current.surface.argbColor)
        .cornerRadius(50)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

struct StopPinMarkerView: View {
    let stopNumber: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(MapThemeColors.current.surface.argbColor)
                .frame(width: 28, height: 28)
            Circle()
                .stroke(MapThemeColors.current.accent.argbColor, lineWidth: 2.5)
                .frame(width: 28, height: 28)
            Text("\(stopNumber)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(MapThemeColors.current.onSurface.argbColor)
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

/// Draws route preview destination/stop markers directly to a bitmap (matches Android `RouteTaggedMarkerBitmap`).
private enum RouteTaggedMarkerBitmap {
    private static let collapsedAddressWidth: CGFloat = 100
    // App theme colours (HOVR greens by default), read when each marker is drawn.
    private static var routeGreenBright: UIColor { MapThemeColors.current.accent.argbUIColor }
    private static var routeGreenPill: UIColor { MapThemeColors.current.accentStrong.argbUIColor }
    private static var routeGreenRing: UIColor { MapThemeColors.current.accent.argbUIColor }
    private static var routeGreenRingInner: UIColor { MapThemeColors.current.accentContainer.argbUIColor }

    static func bitmapFor(tagLabel: String, address: String, expanded: Bool) -> UIImage {
        let displayAddress = address.isEmpty ? tagLabel : address
        let addressFont = UIFont.systemFont(ofSize: 13)
        let tagFont = UIFont.systemFont(ofSize: 13, weight: .bold)
        let addressWidth = addressWidth(expanded: expanded)
        let addressHeight = addressBlockHeight(
            text: displayAddress,
            width: addressWidth,
            expanded: expanded,
            font: addressFont
        )

        let tagWidth = ceil((tagLabel as NSString).size(withAttributes: [.font: tagFont]).width)
        let pillWidth = 14 + tagWidth + 24
        let totalWidth = pillWidth + 8 + addressWidth + 8 + 20 + 4
        let verticalInset: CGFloat = expanded ? 6 : 0
        let totalHeight = max(30, addressHeight) + verticalInset * 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        let size = CGSize(width: totalWidth, height: totalHeight)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let bounds = CGRect(origin: .zero, size: size)
            MapThemeColors.current.surface.argbUIColor.setFill()
            UIBezierPath(roundedRect: bounds, cornerRadius: 15).fill()

            let pillY = (totalHeight - 30) / 2
            let pillRect = CGRect(x: 0, y: pillY, width: pillWidth, height: 30)
            let pillPath = UIBezierPath(
                roundedRect: pillRect,
                byRoundingCorners: [.topLeft, .bottomLeft],
                cornerRadii: CGSize(width: 15, height: 15)
            )
            routeGreenPill.setFill()
            pillPath.fill()

            let iconOrigin = CGPoint(x: pillRect.minX + 12, y: pillRect.midY - 7)
            drawRouteIcon(at: iconOrigin)

            let tagTextSize = (tagLabel as NSString).size(withAttributes: [.font: tagFont])
            let tagRect = CGRect(
                x: iconOrigin.x + 19,
                y: pillY + (30 - tagTextSize.height) / 2,
                width: pillWidth - (iconOrigin.x + 19 - pillRect.minX) - 6,
                height: tagTextSize.height
            )
            let tagStyle = NSMutableParagraphStyle()
            tagStyle.lineBreakMode = .byTruncatingTail
            (tagLabel as NSString).draw(
                in: tagRect,
                withAttributes: [
                    .font: tagFont,
                    .foregroundColor: MapThemeColors.current.onAccent.argbUIColor,
                    .paragraphStyle: tagStyle,
                ]
            )

            let addressX = pillWidth + 8
            let addressY = expanded ? verticalInset : (totalHeight - addressHeight) / 2
            let addressRect = CGRect(x: addressX, y: addressY, width: addressWidth, height: addressHeight)
            let addressStyle = NSMutableParagraphStyle()
            addressStyle.lineBreakMode = .byTruncatingTail
            if expanded {
                addressStyle.maximumLineHeight = addressFont.lineHeight
                addressStyle.minimumLineHeight = addressFont.lineHeight
            }
            (displayAddress as NSString).draw(
                with: addressRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
                attributes: [
                    .font: addressFont,
                    .foregroundColor: MapThemeColors.current.onSurface.argbUIColor,
                    .paragraphStyle: addressStyle,
                ],
                context: nil
            )

            let chevronX = addressX + addressWidth + 8
            let chevronY = (totalHeight - 20) / 2
            if let chevron = UIImage(systemName: "chevron.right")?
                .withTintColor(MapThemeColors.current.onSurface.argbUIColor, renderingMode: .alwaysOriginal) {
                chevron.draw(in: CGRect(x: chevronX, y: chevronY, width: 20, height: 20))
            }
        }
    }

    // The iOS Maps SDK fails to render an over-wide marker icon (renders blank),
    // so the expanded state gains height via a 2nd line rather than screen width.
    private static let expandedAddressWidth: CGFloat = 150

    private static func addressWidth(expanded: Bool) -> CGFloat {
        expanded ? expandedAddressWidth : collapsedAddressWidth
    }

    private static func addressBlockHeight(
        text: String,
        width: CGFloat,
        expanded: Bool,
        font: UIFont
    ) -> CGFloat {
        let singleLine = ceil(font.lineHeight)
        guard expanded else { return singleLine }

        let maxHeight = ceil(font.lineHeight * 2)
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return min(max(ceil(rect.height), singleLine), maxHeight)
    }

    private static func drawRouteIcon(at origin: CGPoint) {
        let outer = CGRect(x: origin.x, y: origin.y, width: 14, height: 14)
        routeGreenRing.setFill()
        UIBezierPath(ovalIn: outer).fill()

        let inner = outer.insetBy(dx: 3, dy: 3)
        routeGreenRingInner.setFill()
        UIBezierPath(ovalIn: inner).fill()

        let center = outer.insetBy(dx: 5, dy: 5)
        routeGreenBright.setFill()
        UIBezierPath(ovalIn: center).fill()
    }
}

final class RouteTaggedMarkerData: NSObject {
    let tagLabel: String
    let address: String
    var expanded: Bool

    init(tagLabel: String, address: String, expanded: Bool = false) {
        self.tagLabel = tagLabel
        self.address = address
        self.expanded = expanded
        super.init()
    }

    /// Wrap the pre-rendered bitmap in a plain `UIImageView` and drive it through
    /// `iconView` + `tracksViewChanges` — the same marker pattern the start/ETA
    /// pin uses successfully in this map. A static wide `icon` UIImage does not
    /// paint reliably, but an `iconView` image view does.
    private func makeIconView() -> UIImageView {
        let image = RouteTaggedMarkerBitmap.bitmapFor(
            tagLabel: tagLabel,
            address: address,
            expanded: expanded
        )
        print("🖼️ RouteTaggedMarker makeIconView: expanded=\(expanded) iconSize=\(image.size) tag=\(tagLabel)")
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageView.contentMode = .center
        imageView.backgroundColor = .clear
        return imageView
    }

    private func apply(to marker: GMSMarker) {
        marker.icon = nil
        marker.iconView = makeIconView()
        marker.groundAnchor = CGPoint(x: 0.099, y: 0.1)
        marker.appearAnimation = .none
        marker.tracksViewChanges = true
    }

    func attach(to marker: GMSMarker) {
        apply(to: marker)
    }

    func toggleExpanded(on marker: GMSMarker, mapView: GMSMapView) {
        expanded.toggle()
        print("🔁 toggleExpanded -> expanded=\(expanded) — swapping iconView")
        marker.iconView = makeIconView()
        marker.tracksViewChanges = true
        print("✅ toggleExpanded done — iconView swapped, size=\(marker.iconView?.frame.size ?? .zero)")
    }
}

struct GoogleMapsWithRoute: View {
    var result: FlutterResult?
    var flutterMethod: FlutterMethodCall?
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
    var usePickupAddressMarker: Bool = false
    var useDropoffAddressMarker: Bool = false
    var disableUserInteraction: Bool = false

    var body: some View {
        GoogleMapsWithRouteViewController(
            zoom: zoomLevel,
            destinationLocation: destinationLocation,
            originLocation: originLocation,
            startLocationAddress: pickUpAddress,
            dropOffLocationAddress: dropOffAddress,
            controller: mapController,
            routeFetcher: routeData,
            stops: stops,
            usePickupAddressMarker: usePickupAddressMarker,
            useDropoffAddressMarker: useDropoffAddressMarker,
            disableUserInteraction: disableUserInteraction
        )
        .edgesIgnoringSafeArea(.all)
    }
}


