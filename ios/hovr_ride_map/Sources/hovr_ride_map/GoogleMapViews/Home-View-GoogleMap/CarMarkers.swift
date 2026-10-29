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
    private var icon: UIImage
    private var markersById: [String: GMSMarker] = [:]
    private var lastFix: [String: CarFix] = [:]
    private var lastUpdateTime: [String: TimeInterval] = [:]
    private var moveAnimations: [String: CarAnimation] = [:]
    private var rotAnimations: [String: CarAnimation] = [:]
    private var nextPruneAt: TimeInterval = 0
    private let minDt: TimeInterval
    private static let MAX_UPDATE_RATE_HZ = 5.0

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

    /// Movement-based heading — ignores noisy payload bearing when the car actually moved.
    private func movementHeading(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> Float? {
        let dist = distanceMeters(a: start, b: end)
        guard dist >= MapConstants.MICRO_MOVE_THRESHOLD_METERS else { return nil }
        return bearingDegrees(a: start, b: end)
    }

    private func animateMarker(
        id: String,
        marker: GMSMarker,
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        targetHeadingDeg: Float?,
        durationMs: TimeInterval
    ) {
        cancelAnimations(for: id)

        let move = CarAnimation(duration: durationMs / 1000.0) { [weak marker] progress in
            guard let marker = marker else { return }
            let position = slerpLatLng(a: start, b: end, t: Float(progress))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            marker.position = position
            CATransaction.commit()
        }
        move.onComplete = { [weak marker] in
            guard let marker = marker else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            marker.position = end
            CATransaction.commit()
        }
        moveAnimations[id] = move
        move.start()

        if let targetHeading = targetHeadingDeg {
            let rotateMs = min(durationMs, 250.0)
            animateBearing(
                id: id,
                marker: marker,
                from: Float(marker.rotation),
                toRaw: targetHeading,
                duration: rotateMs / 1000.0
            )
        }
    }

    func upsert(fixes: [CarFix], nowMs: TimeInterval = CACurrentMediaTime()) {
        if nowMs >= nextPruneAt {
            let staleIds = lastUpdateTime
                .filter { nowMs - $0.value > Double(MapConstants.DEFAULT_INACTIVE_TIMEOUT_MS) / 1000.0 }
                .map { $0.key }
            for id in staleIds {
                cancelAnimations(for: id)
                markersById.removeValue(forKey: id)?.map = nil
                lastFix.removeValue(forKey: id)
                lastUpdateTime.removeValue(forKey: id)
            }
            nextPruneAt = nowMs + (Double(MapConstants.DEFAULT_PRUNE_EVERY_MS) / 1000.0)
        }

        let capMps: Float = 10.0
        let mixAlpha: Float = 0.30

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

            let dist = distanceMeters(a: start, b: end)

            let rawSpeed = max(fix.speedMps ?? prev?.speedMps ?? 12, 0.1)
            let observedSpeed = dtSec > 0 ? Float(dist) / Float(dtSec) : rawSpeed
            let cappedRaw = min(rawSpeed, capMps)
            let cappedObs = min(observedSpeed, capMps)
            let effSpeed = max((1.0 - mixAlpha) * cappedRaw + mixAlpha * cappedObs, 0.1)

            let expected = effSpeed * Float(dtSec)
            let dynTeleport = max(
                MapConstants.BASE_TELEPORT_DIST_M,
                Double(expected) * MapConstants.TELEPORT_FACTOR
            )

            if dist > dynTeleport {
                cancelAnimations(for: fix.id)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                marker.position = end
                if let heading = movementHeading(start: start, end: end) ?? fix.bearingDeg {
                    marker.rotation = CLLocationDegrees(normalize360(heading))
                }
                CATransaction.commit()
            } else if dist < MapConstants.MICRO_MOVE_THRESHOLD_METERS {
                // Snap small stream deltas so the trip driver stays aligned with live GPS.
                cancelAnimations(for: fix.id)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                marker.position = end
                if let heading = movementHeading(start: start, end: end) ?? fix.bearingDeg {
                    marker.rotation = CLLocationDegrees(normalize360(heading))
                }
                CATransaction.commit()
            } else {
                let duration = calculateAnimationDuration(
                    distanceMeters: dist,
                    speedMps: effSpeed,
                    previousSpeedMps: effSpeed,
                    timeSinceLastUpdateMs: Int64(dtSec * 1000)
                )
                let heading = movementHeading(start: start, end: end)
                animateMarker(
                    id: fix.id,
                    marker: marker,
                    start: start,
                    end: end,
                    targetHeadingDeg: heading,
                    durationMs: TimeInterval(duration)
                )
            }

            lastFix[fix.id] = fix
            lastUpdateTime[fix.id] = nowMs
        }
    }

    /// Swaps the car icon on every marker, e.g. after the app theme changed.
    func setIcon(_ newIcon: UIImage) {
        icon = newIcon
        for marker in markersById.values { marker.icon = newIcon }
    }

    func marker(for id: String) -> GMSMarker? {
        markersById[id]
    }
}
