//
//  RideStateControllers.swift
//  HOVR
//

import Combine
import Foundation

class PolylineController: ObservableObject {
    static let shared = PolylineController()

    @Published var polyline: [String: Any] = [:] {
        didSet {
            savePolyline()
        }
    }

    private let userDefaultsKey = "savedPolyline"

    private init() {
        loadPolyline()
    }

    private func savePolyline() {
        if let encoded = polyline["polyline"] as? String, !encoded.isEmpty {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("💾 Polyline saved to UserDefaults")
        }
    }

    private func loadPolyline() {
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey),
           !saved.isEmpty {
            polyline = ["polyline": saved]
            print("📥 Polyline loaded from UserDefaults: \(saved.prefix(50))...")
        } else {
            print("⚠️ No saved polyline found in UserDefaults")
        }
    }

    func updatePolyline(_ encodedPolyline: String) {
        polyline = ["polyline": encodedPolyline]
    }

    func clearPolyline() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        let encoded = polyline["polyline"] as? String ?? ""
        guard !encoded.isEmpty else { return }
        polyline = [:]
        print("🗑️ Polyline cleared from UserDefaults")
    }
}

class DriverLocationController: ObservableObject {
    static let shared = DriverLocationController()

    @Published var driverLocation: [String: Any] = [:] {
        didSet {
            saveDriverLocation()
        }
    }

    private let userDefaultsKey = "savedDriverLocation"

    private init() {
        loadDriverLocation()
    }

    private func saveDriverLocation() {
        guard
            let lat = driverLocation["lat"] as? Double,
            let lng = driverLocation["lng"] as? Double
        else {
            return
        }

        let dict: [String: Any] = [
            "lat": lat,
            "lng": lng
        ]

        UserDefaults.standard.set(dict, forKey: userDefaultsKey)
        print("💾 Driver location saved: \(lat), \(lng)")
    }

    private func loadDriverLocation() {
        if let saved = UserDefaults.standard.dictionary(forKey: userDefaultsKey),
           let lat = saved["lat"] as? Double,
           let lng = saved["lng"] as? Double {
            driverLocation = ["lat": lat, "lng": lng]
            print("📥 Loaded saved driver location: \(lat), \(lng)")
        } else {
            print("⚠️ No saved driver location found in UserDefaults")
        }
    }

    func updateDriverLocation(lat: Double, lng: Double) {
        driverLocation = [
            "lat": lat,
            "lng": lng
        ]
        print("📍 Driver location updated manually: \(lat), \(lng)")
    }

    func clearDriverLocation() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        driverLocation = [:]
        print("🗑️ Driver location cleared")
    }
}

class TripDropoffController: ObservableObject {
    static let shared = TripDropoffController()

    @Published private(set) var coordinate: (lat: Double, lng: Double)?

    private init() {}

    func update(lat: Double, lng: Double) {
        coordinate = (lat, lng)
    }

    func clear() {
        coordinate = nil
    }
}

class TripPickupController: ObservableObject {
    static let shared = TripPickupController()

    @Published private(set) var coordinate: (lat: Double, lng: Double)?

    private init() {}

    func update(lat: Double, lng: Double) {
        coordinate = (lat, lng)
    }

    func clear() {
        coordinate = nil
    }
}

class TripUserController: ObservableObject {
    static let shared = TripUserController()

    @Published private(set) var coordinate: (lat: Double, lng: Double)?

    private init() {}

    func update(lat: Double, lng: Double) {
        coordinate = (lat, lng)
    }

    func clear() {
        coordinate = nil
    }
}

struct TripStopCoordinate: Equatable {
    let lat: Double
    let lng: Double
    let address: String
    let index: Int
}

class TripStopsController: ObservableObject {
    static let shared = TripStopsController()

    @Published private(set) var stops: [TripStopCoordinate] = []

    private init() {}

    func update(rawStops: [[String: Any]]) {
        var parsed: [TripStopCoordinate] = []
        for item in rawStops {
            guard let lat = doubleValue(item["latitude"]),
                  let lng = doubleValue(item["longitude"])
            else {
                continue
            }
            if lat == 0, lng == 0 { continue }
            let address = item["address"] as? String ?? ""
            parsed.append(
                TripStopCoordinate(
                    lat: lat,
                    lng: lng,
                    address: address,
                    index: parsed.count + 1
                )
            )
        }
        stops = parsed
    }

    func clear() {
        stops = []
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
