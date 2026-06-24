//
//  CarMarkers.swift
//  HOVR
//
//  Created by Bipan Sharma on 02/10/25.
//
import UIKit
import CoreLocation
import GoogleMaps

final class CarMarkers {
    private let map: GMSMapView
    private let icon: UIImage
    private var markersById: [String: GMSMarker] = [:]
    private var lastFix: [String: CarFix] = [:]
    private var lastUpdateTime: [String: TimeInterval] = [:]
    private var moveAnimations: [String: CarAnimation] = [:]
    private var rotAnimations: [String: CarAnimation] = [:]
    private var nextPruneAt: TimeInterval = 0
    private let minDt: TimeInterval
    private static let MAX_UPDATE_RATE_HZ = 5.0
        // --- Heading smoothing (prevents skid on turns) ---
    private var headingEMA: [String: Float] = [:]
    private let headingAlpha: Float = 0.30   // 0.15–0.35 good range
    private let maxDisplaySpeedMps: Float = 10.0   // cap visual speed (~36 km/h)
                                                   //    private let visualSpeedScale: Float = 1.00     // >1.0 = faster, <1.0 = slower
    private var visualSpeedScale: Float = 1.00   // can be changed at runtime
    
    
    init(map: GMSMapView, icon: UIImage) {
        self.map = map
        self.icon = icon
        self.minDt = 1.0 / Self.MAX_UPDATE_RATE_HZ
    }
    
    private func cancelAnimations(for id: String) {
        moveAnimations.removeValue(forKey: id)?.cancel()
        rotAnimations.removeValue(forKey: id)?.cancel()
    }
    
    private func animateBearing(id: String, marker: GMSMarker, from: Float, toRaw: Float, duration: TimeInterval = 0.2) {
        let to = shortestHeadingTarget(from: from, to: toRaw)
        rotAnimations.removeValue(forKey: id)?.cancel()
        let anim = CarAnimation(duration: duration) { [weak marker] progress in
            guard let marker = marker else { return }
            let bearing = from + (normalizeDelta(to - from) * Float(progress))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            marker.rotation = CLLocationDegrees(normalize360(bearing))
            CATransaction.commit()
        }
        rotAnimations[id] = anim
        anim.start()
    }
    
    private func effectiveSpeed(id: String, raw: Float) -> Float {
        let last = headingEMA[id] ?? raw
        let smoothed = last + (raw - last) * headingAlpha
        headingEMA[id] = smoothed
            // cap, then optionally scale down to slow globally
        return min(smoothed, maxDisplaySpeedMps) * (1.0 / visualSpeedScale)
    }
    
    private func animateMarker(
        id: String,
        marker: GMSMarker,
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        targetHeadingDeg: Float?,
        durationMs: TimeInterval
    )
        //    {
        //        cancelAnimations(for: id)
        //
        //        let move = CarAnimation(duration: durationMs / 1000.0) { [weak marker] progress in
        //            guard let marker = marker else { return }
        //            let position = slerpLatLng(a: start, b: end, t: Float(progress))
        //            CATransaction.begin()
        //            CATransaction.setDisableActions(true)
        //            marker.position = position
        //            CATransaction.commit()
        //        }
        //        move.onComplete = { [weak marker] in
        //            guard let marker = marker else { return }
        //            CATransaction.begin()
        //            CATransaction.setDisableActions(true)
        //            marker.position = end
        //            CATransaction.commit()
        //        }
        //        moveAnimations[id] = move
        //        move.start()
        //
        //        if let targetHeading = targetHeadingDeg {
        //            let rotateMs = min(durationMs, 250.0)
        //            animateBearing(id: id, marker: marker, from: Float(marker.rotation), toRaw: targetHeading, duration: rotateMs / 1000.0)
        //        }
        //    }
    
    {
    cancelAnimations(for: id)
    
        // Drive rotation by path tangent each frame (prevents skid)
    let move = CarAnimation(duration: durationMs / 1000.0) { [weak self, weak marker] progress in
        guard let self = self, let marker = marker else { return }
        
            // Current position along the geodesic path
        let t = Float(progress)
        let pos = slerpLatLng(a: start, b: end, t: t)
        
            // A tiny look-behind to estimate local tangent (clamped to [0,1])
        let tPrev = max(t - 0.02, 0.0)
        let prevPos = tPrev > 0 ? slerpLatLng(a: start, b: end, t: tPrev) : start
        
            // Instantaneous heading
        let inst = bearingDegrees(a: prevPos, b: pos)
        
            // Smooth with EMA
        let last = self.headingEMA[id] ?? Float(marker.rotation)
        let blended = last + normalizeDelta(inst - last) * self.headingAlpha
        self.headingEMA[id] = normalize360(blended)
        
            // Apply without implicit Core Animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        marker.position = pos
        marker.rotation = CLLocationDegrees(self.headingEMA[id] ?? blended)
        CATransaction.commit()
    }
    
        // Final snap to exact end; gently align to final tangent
    move.onComplete = { [weak self, weak marker] in
        guard let self = self, let marker = marker else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        marker.position = end
        let finalHeading = bearingDegrees(a: start, b: end)
        let last = self.headingEMA[id] ?? Float(marker.rotation)
        let blended = last + normalizeDelta(finalHeading - last) * 0.5
        marker.rotation = CLLocationDegrees(normalize360(blended))
        CATransaction.commit()
    }
    
    moveAnimations[id] = move
    move.start()
    
        // NOTE: no separate rotate animation needed anymore.
    }
    
    
        //    func upsert(fixes: [CarFix], nowMs: TimeInterval = CACurrentMediaTime()) {
        //        // Prune inactive markers occasionally
        //        if nowMs >= nextPruneAt {
        //            let staleIds = lastUpdateTime
        //                .filter { nowMs - $0.value > Double(MapConstants.DEFAULT_INACTIVE_TIMEOUT_MS)/1000.0 }
        //                .map { $0.key }
        //            for id in staleIds {
        //                cancelAnimations(for: id)
        //                markersById.removeValue(forKey: id)?.map = nil
        //                lastFix.removeValue(forKey: id)
        //                lastUpdateTime.removeValue(forKey: id)
        //            }
        //            nextPruneAt = nowMs + (Double(MapConstants.DEFAULT_PRUNE_EVERY_MS) / 1000.0)
        //        }
        //
        //        for fix in fixes {
        //            let marker: GMSMarker
        //            if let existing = markersById[fix.id] {
        //                marker = existing
        //            } else {
        //                let m = GMSMarker()
        //                m.position = CLLocationCoordinate2D(latitude: fix.lat, longitude: fix.lng)
        //                m.icon = icon
        //                m.isFlat = true
        //                m.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        //                m.rotation = CLLocationDegrees(fix.bearingDeg ?? 0)
        //                m.map = map
        //                markersById[fix.id] = m
        //                marker = m
        //            }
        //
        //            let prev = lastFix[fix.id]
        //            let start = prev != nil
        //                ? CLLocationCoordinate2D(latitude: prev!.lat, longitude: prev!.lng)
        //                : CLLocationCoordinate2D(latitude: fix.lat, longitude: fix.lng)
        //            let end = CLLocationCoordinate2D(latitude: fix.lat, longitude: fix.lng)
        //            let dtSec = max(nowMs - (lastUpdateTime[fix.id] ?? 0), 0)
        //            if dtSec < minDt { continue }
        //
        //            let dist = distanceMeters(a: start, b: end)
        //            let speed = max(fix.speedMps ?? prev?.speedMps ?? 12, 0.1)
        //            let expected = speed * Float(dtSec) // meters we’d expect in dt
        //            let dynTeleport = max(MapConstants.BASE_TELEPORT_DIST_M, Double(expected) * MapConstants.TELEPORT_FACTOR)
        //
        //            if dist > dynTeleport {
        //                cancelAnimations(for: fix.id)
        //                CATransaction.begin()
        //                CATransaction.setDisableActions(true)
        //                marker.position = end
        //                if let bearing = fix.bearingDeg {
        //                    marker.rotation = CLLocationDegrees(normalize360(bearing))
        //                }
        //                CATransaction.commit()
        //            } else if dist < MapConstants.MICRO_MOVE_THRESHOLD_METERS {
        //                if let newHeading = fix.bearingDeg {
        //                    let delta = abs(normalizeDelta(newHeading - Float(marker.rotation)))
        //                    if delta >= MapConstants.HEADING_DEADZONE_DEG {
        //                        animateBearing(id: fix.id, marker: marker, from: Float(marker.rotation), toRaw: newHeading, duration: 0.2)
        //                    }
        //                }
        //            } else {
        //                let duration = calculateAnimationDuration(
        //                    distanceMeters: dist,
        //                    speedMps: fix.speedMps,
        //                    previousSpeedMps: prev?.speedMps,
        //                    timeSinceLastUpdateMs: Int64(dtSec * 1000)
        //                )
        //                animateMarker(id: fix.id, marker: marker, start: start, end: end,
        //                              targetHeadingDeg: fix.bearingDeg, durationMs: TimeInterval(duration))
        //            }
        //
        //            lastFix[fix.id] = fix
        //            lastUpdateTime[fix.id] = nowMs
        //        }
        //    }
    
    func upsert(fixes: [CarFix], nowMs: TimeInterval = CACurrentMediaTime()) {
            // Prune inactive markers occasionally
        if nowMs >= nextPruneAt {
            let staleIds = lastUpdateTime
                .filter { nowMs - $0.value > Double(MapConstants.DEFAULT_INACTIVE_TIMEOUT_MS)/1000.0 }
                .map { $0.key }
            for id in staleIds {
                cancelAnimations(for: id)
                markersById.removeValue(forKey: id)?.map = nil
                lastFix.removeValue(forKey: id)
                lastUpdateTime.removeValue(forKey: id)
            }
            nextPruneAt = nowMs + (Double(MapConstants.DEFAULT_PRUNE_EVERY_MS) / 1000.0)
        }
        
            // --- Speed governor knobs (tune here) ---
        let capMps: Float = 10.0        // visual speed cap (~36 km/h); lower => slower
        let mixAlpha: Float = 0.30      // blend raw v. observed; higher => reacts faster
                                        // ----------------------------------------
        
        for fix in fixes {
            let marker: GMSMarker
            if let existing = markersById[fix.id] {
                marker = existing
            } else {
                let m = GMSMarker()
                m.position = CLLocationCoordinate2D(latitude: fix.lat, longitude: fix.lng)
                m.icon = icon
                m.isFlat = true
                m.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                m.rotation = CLLocationDegrees(fix.bearingDeg ?? 0)
                m.map = map
                markersById[fix.id] = m
                marker = m
            }
            
            let prev = lastFix[fix.id]
            let start = prev != nil
            ? CLLocationCoordinate2D(latitude: prev!.lat, longitude: prev!.lng)
            : CLLocationCoordinate2D(latitude: fix.lat, longitude: fix.lng)
            let end = CLLocationCoordinate2D(latitude: fix.lat, longitude: fix.lng)
            
            let dtSec = max(nowMs - (lastUpdateTime[fix.id] ?? 0), 0)
            if dtSec < minDt { continue }
            
            let dist = distanceMeters(a: start, b: end) // meters
            
                // ---------- Speed governor (slows animations safely) ----------
                // Raw speed from payload (fallbacks to previous → default 12 m/s)
            let rawSpeed = max(fix.speedMps ?? prev?.speedMps ?? 12, 0.1)
                // Observed speed from geometry (dist over dt)
            let observedSpeed = dtSec > 0 ? Float(dist) / Float(dtSec) : rawSpeed
                // Cap both, then blend (light smoothing)
            let cappedRaw = min(rawSpeed, capMps)
            let cappedObs = min(observedSpeed, capMps)
            let effSpeed = max((1.0 - mixAlpha) * cappedRaw + mixAlpha * cappedObs, 0.1)
                // Use the same effective speed everywhere below
                // --------------------------------------------------------------
            
                // Teleport bound scales with effective speed so “slow-mo” doesn’t cause surprise teleports
            let expected = effSpeed * Float(dtSec) // meters expected during dt
            let dynTeleport = max(MapConstants.BASE_TELEPORT_DIST_M,
                                  Double(expected) * MapConstants.TELEPORT_FACTOR)
            
            if dist > dynTeleport {
                    // Too far → snap
                cancelAnimations(for: fix.id)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                marker.position = end
                if let bearing = fix.bearingDeg {
                    marker.rotation = CLLocationDegrees(normalize360(bearing))
                }
                CATransaction.commit()
                
            } else if dist < MapConstants.MICRO_MOVE_THRESHOLD_METERS {
                    // Tiny move → rotate only if needed
                if let newHeading = fix.bearingDeg {
                    let delta = abs(normalizeDelta(newHeading - Float(marker.rotation)))
                    if delta >= MapConstants.HEADING_DEADZONE_DEG {
                            // keep short; rotation during move is already tangent-driven
                        animateBearing(id: fix.id, marker: marker,
                                       from: Float(marker.rotation), toRaw: newHeading, duration: 0.18)
                    }
                }
                
            } else {
                    // Animate: pass the **effective** speed so duration lengthens (slower car)
                let duration = calculateAnimationDuration(
                    distanceMeters: dist,
                    speedMps: effSpeed,
                    previousSpeedMps: effSpeed,
                    timeSinceLastUpdateMs: Int64(dtSec * 1000)
                )
                animateMarker(id: fix.id,
                              marker: marker,
                              start: start,
                              end: end,
                              targetHeadingDeg: fix.bearingDeg,
                              durationMs: TimeInterval(duration))
            }
            
            lastFix[fix.id] = fix
            lastUpdateTime[fix.id] = nowMs
        }
    }
    
    func setVisualSpeedScale(_ scale: Float) {
        visualSpeedScale = max(0.3, min(scale, 2.0))    }
    
}
