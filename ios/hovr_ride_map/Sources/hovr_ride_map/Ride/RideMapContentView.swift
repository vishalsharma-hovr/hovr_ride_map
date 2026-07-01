import CoreLocation
import SwiftUI

/// SwiftUI shell for the unified in-trip map (all ride-map modes).
struct RideMapContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var zoomLevel: Float = 16.5
    @ObservedObject private var mapController = GoogleMapsPlugin.sharedMapController
    @ObservedObject private var polylineController = PolylineController.shared
    @ObservedObject private var tripStage = TripStageController.shared

    var body: some View {
        ZStack {
            if let location = locationManager.location {
                RideMapViewRepresentable(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    zoom: zoomLevel,
                    locationManager: locationManager,
                    controller: mapController,
                    polylineController: polylineController,
                    driverLocation: DriverLocationController.shared,
                    tripStage: tripStage.tripStage
                )
                .ignoresSafeArea()
            } else {
                ProgressView()
            }
        }
    }
}
