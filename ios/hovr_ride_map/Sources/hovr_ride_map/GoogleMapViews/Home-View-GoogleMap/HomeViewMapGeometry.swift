//
//  HomeViewMapGeometry.swift
//  HOVR
//

import CoreLocation
import Foundation

struct MapConstants {
    static let MICRO_MOVE_THRESHOLD_METERS: Double = 2.0
    static let MIN_ANIM_MS: Int64 = 150
    static let ABS_MAX_ANIM_MS: Int64 = 6000
    static let HEADING_DEADZONE_DEG: Float = 7.0
    static let DEFAULT_INACTIVE_TIMEOUT_MS: Int64 = 15_000
    static let DEFAULT_PRUNE_EVERY_MS: Int64 = 2_000
    static let BASE_TELEPORT_DIST_M: Double = 200.0
    static let TELEPORT_FACTOR: Double = 2.5
    static let SPEED_SLOWDOWN: Float = 2.6
}

struct CarFix {
    let id: String
    let lat: Double
    let lng: Double
    let bearingDeg: Float?
    let speedMps: Float?
    let timestampMs: Int64
}

struct Waypoint {
    let lat: Double
    let lng: Double
    let bearingDeg: Float
}

@inline(__always)
func wp(lat: Double, lng: Double, bearingDeg: Float) -> Waypoint {
    Waypoint(lat: lat, lng: lng, bearingDeg: bearingDeg)
}

@inline(__always)
func distanceMeters(a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> Double {
    let latAvgRad = (a.latitude + b.latitude) / 2.0 * .pi / 180.0
    let dx = (b.longitude - a.longitude) * 111_320.0 * cos(latAvgRad)
    let dy = (b.latitude - a.latitude) * 110_540.0
    return sqrt(dx * dx + dy * dy)
}

@inline(__always)
func normalize360(_ deg: Float) -> Float {
    var result = deg.truncatingRemainder(dividingBy: 360)
    if result < 0 { result += 360 }
    return result
}

@inline(__always)
func normalizeDelta(_ d: Float) -> Float {
    var x = (d + 540).truncatingRemainder(dividingBy: 360) - 180
    if x < -180 { x += 360 }
    return x
}

@inline(__always)
func shortestHeadingTarget(from: Float, to: Float) -> Float {
    let df = normalizeDelta(to - from)
    return normalize360(from + df)
}

@inline(__always)
func bearingDegrees(a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> Float {
    let φ1 = a.latitude * .pi / 180.0
    let φ2 = b.latitude * .pi / 180.0
    let Δλ = (b.longitude - a.longitude) * .pi / 180.0
    let y = sin(Δλ) * cos(φ2)
    let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
    var θ = atan2(y, x) * 180.0 / .pi
    if θ < 0 { θ += 360 }
    return Float(θ)
}

func slerpLatLng(a: CLLocationCoordinate2D, b: CLLocationCoordinate2D, t: Float) -> CLLocationCoordinate2D {
    let lat1 = a.latitude * .pi / 180.0
    let lng1 = a.longitude * .pi / 180.0
    let lat2 = b.latitude * .pi / 180.0
    let lng2 = b.longitude * .pi / 180.0
    
    let dLat = lat2 - lat1
    let dLng = lng2 - lng1
    let sinHalfD = sqrt(pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLng / 2), 2))
    let d = 2 * asin(sinHalfD)
    
    if d == 0 { return a }
    
    let A = sin((1 - Double(t)) * d) / sin(d)
    let B = sin(Double(t) * d) / sin(d)
    
    let x = A * cos(lat1) * cos(lng1) + B * cos(lat2) * cos(lng2)
    let y = A * cos(lat1) * sin(lng1) + B * cos(lat2) * sin(lng2)
    let z = A * sin(lat1) + B * sin(lat2)
    
    let outLat = atan2(z, sqrt(x * x + y * y)) * 180.0 / .pi
    let outLng = atan2(y, x) * 180.0 / .pi
    
    return CLLocationCoordinate2D(latitude: outLat, longitude: outLng)
}

func calculateAnimationDuration(
    distanceMeters: Double,
    speedMps: Float?,
    previousSpeedMps: Float?,
    timeSinceLastUpdateMs: Int64
) -> Int64 {
    let speed = max((speedMps ?? previousSpeedMps ?? 10.0) / MapConstants.SPEED_SLOWDOWN, 0.1)
    let idealMs = Int64((distanceMeters / Double(speed)) * 1000.0)
    let cadenceCap = max(Int64(Double(timeSinceLastUpdateMs) * 0.9), MapConstants.MIN_ANIM_MS)
    let cadenceBound = min(cadenceCap, MapConstants.ABS_MAX_ANIM_MS)
    let bufferedIdeal = Int64(Double(idealMs) * 1.05)
    return min(max(bufferedIdeal, MapConstants.MIN_ANIM_MS), min(cadenceBound, MapConstants.ABS_MAX_ANIM_MS))
}

func parseNearbyDrivers(raw: [[String: Any]]) -> [CarFix] {
    var fixes: [CarFix] = []
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    
    func toFloat(_ value: Any?) -> Float? {
        if let num = value as? NSNumber {
            return num.floatValue
        } else if let str = value as? String {
            return Float(str.trimmingCharacters(in: CharacterSet(charactersIn: "fF")))
        }
        return nil
    }
    
    func toDouble(_ value: Any?) -> Double? {
        if let num = value as? NSNumber {
            return num.doubleValue
        } else if let str = value as? String {
            return Double(str.trimmingCharacters(in: CharacterSet(charactersIn: "fF")))
        }
        return nil
    }
    
    func extractLatLng(_ m: [String: Any]) -> (Double, Double)? {
        if let lat = toDouble(m["lat"] ?? m["latitude"]),
           let lng = toDouble(m["lng"] ?? m["longitude"]) {
            return (lat, lng)
        }
        if let pos = m["position"] as? [String: Any]
            ?? m["pos"] as? [String: Any]
            ?? m["location"] as? [String: Any] {
            if let lat = toDouble(pos["lat"] ?? pos["latitude"]),
               let lng = toDouble(pos["lng"] ?? pos["longitude"]) {
                return (lat, lng)
            }
        }
        return nil
    }
    
    for item in raw {
        guard let id = (item["id"] ?? item["driverId"] ?? item["driver_id"]) as? String,
              let (lat, lng) = extractLatLng(item) else { continue }
        
        let bearingRaw = item["bearingDegrees"]
        ?? item["headingDeg"]
        ?? item["heading"]
        ?? (item["position"] as? [String: Any])?["bearingDeg"]
        let bearing = toFloat(bearingRaw).map { normalize360($0) }
        
        var speedMps = toFloat(item["speed_mps"] ?? item["speedMps"] ?? item["speed"])
        if speedMps == nil,
           let kmh = toFloat(item["speed_kmh"] ?? item["speedKmh"] ?? (item["velocity"] as? [String: Any])?["kmh"]) {
            speedMps = kmh / 3.6
        }
        
        var ts = now
        if let tsAny = item["timestampMs"] ?? item["ts"] ?? item["timestamp"] {
            if let tsNum = tsAny as? Int64 {
                ts = tsNum < 1_000_000_000_000 ? tsNum * 1000 : tsNum
            } else if let tsNum32 = tsAny as? Int, tsNum32 > 0 {
                let v = Int64(tsNum32)
                ts = v < 1_000_000_000_000 ? v * 1000 : v
            } else if let tsStr = tsAny as? String, let tsVal = Int64(tsStr) {
                ts = tsVal
            }
        }
        
        fixes.append(CarFix(id: id, lat: lat, lng: lng, bearingDeg: bearing, speedMps: speedMps, timestampMs: ts))
    }
    return fixes
}
