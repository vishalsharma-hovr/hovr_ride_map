import Foundation
import GoogleMaps

/// Direct bridge from `ride-view-channel` recenter calls to the active ride map view.
final class RideMapRecenterRegistry {
    static let shared = RideMapRecenterRegistry()

    private weak var coordinator: RideMapViewRepresentable.Coordinator?

    private init() {}

    func bind(coordinator: RideMapViewRepresentable.Coordinator) {
        self.coordinator = coordinator
    }

    func unbind(coordinator: RideMapViewRepresentable.Coordinator) {
        guard self.coordinator === coordinator else { return }
        self.coordinator = nil
    }

    @discardableResult
    func requestRecenter(fit: String?) -> Bool {
        guard
            let coordinator,
            let mapView = coordinator.mapView
        else {
            NSLog("⚠️ [hovr_ride_map] recenter skipped — no active ride map view")
            return false
        }

        coordinator.performRecenterRequest(fit: fit)
        return true
    }
}