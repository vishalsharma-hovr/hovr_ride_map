//
//  HomeViewGoogleMapIOS.swift
//  HOVR
//

import Foundation
import CoreLocation
import GoogleMaps
import UIKit
import QuartzCore
import Flutter
import Combine

final class HomeViewGoogleMapIOS: NSObject, FlutterPlatformView {
    private static var instanceStack: [HomeViewGoogleMapIOS] = []
    private static let instanceStackLock = NSLock()

    private let mapView: GMSMapView
    private let locationManager: CLLocationManager
    private var carMarkers: CarMarkers!  // Force unwrapped - will always be initialized
    /// Untinted car artwork and the theme colour it was last painted in.
    private var carIconBase: UIImage?
    private var carIconTint: UInt32?
    private var carIconFestiveVersion = -1
    private var startMarker: GMSMarker?
    private var firstFix = true
    
    // Pending batches
    private var pendingDriverBatches: [[CarFix]] = []
    private let pendingBatchesLock = NSLock()
    
    // Driver tracking
    private var expectedDriverCount = 0
    private var actualDriverCount = 0
    private var driversShownIds: Set<String> = []
    
    // Method channels
    private let reCenterChannel: FlutterMethodChannel
    private let driversChannel: FlutterMethodChannel
    
    // Buffer/drainer
    private var inbox: [String: [CarFix]] = [:]
    private var bufferPaused = false
    private var pendingStartDelayMs: TimeInterval = 0.001
    private var drainIntervalMs: TimeInterval = 0.35
    private static let MIN_TICK_MS: TimeInterval = 0.120
    private static let MAX_ACTIVE_DRIVERS = 12
    private static let MAX_QUEUE_PER_DRIVER = 30
    
    // GCD timer
    private var drainSrc: DispatchSourceTimer?
    private var lastDrainFiredAt: TimeInterval = CACurrentMediaTime()
    
    // Observes the shared recenter flag toggled from Flutter via com.hovr/global_channel
    private var cancellables = Set<AnyCancellable>()
    
    init(
        frame: CGRect,
        messenger: FlutterBinaryMessenger,
        viewId: Int64,
        initialLatitude: Double? = nil,
        initialLongitude: Double? = nil
    ) {
        let hasInitialCoords = initialLatitude != nil && initialLongitude != nil &&
            (initialLatitude != 0.0 || initialLongitude != 0.0)
        let cameraLat = hasInitialCoords ? initialLatitude! : 0.0
        let cameraLng = hasInitialCoords ? initialLongitude! : 0.0
        let camera = GMSCameraPosition.camera(withLatitude: cameraLat, longitude: cameraLng, zoom: 15)
        self.mapView = GMSMapView.map(withFrame: frame, camera: camera)
        self.locationManager = CLLocationManager()
        self.reCenterChannel = FlutterMethodChannel(name: "ride-view-channel", binaryMessenger: messenger)
        self.driversChannel = FlutterMethodChannel(name: "show-drivers-location-on-map", binaryMessenger: messenger)
        
        super.init()
        
        if hasInitialCoords {
            self.firstFix = false
        }
        
        // print("🟢 ==================== INIT START ====================")
        // print("🟢 ViewId: \(viewId)")
        // print("🟢 Time: \(Date())")
        
        // CRITICAL: Initialize CarMarkers SYNCHRONOUSLY before anything else
        self.carMarkers = self.createCarMarkers()
        // print("🟢 CarMarkers created: \(self.carMarkers != nil)")
        
        setupMapView()
        MapStylePolicy.shared.attach(mapView)
        setupLocationManager()
        registerWithStack()
        observeRecenterFlag()
        
        // Process any pending batches immediately
        DispatchQueue.main.async { [weak self] in
            self?.processPendingDriverBatches()
        }
        
        // print("🟢 ==================== INIT COMPLETE ====================")
    }
    
    func view() -> UIView {
        // print("🟢 view() called, returning mapView")
        return mapView
    }
    
    // CRITICAL: Synchronous CarMarkers creation
    private func createCarMarkers() -> CarMarkers {
        print("🟢 Creating CarMarkers synchronously...")
        
        var icon: UIImage?
        
        // Try multiple icon names
        let iconNames = ["car-icon", "car_icon", "carIcon", "car"]
        for name in iconNames {
            if let img = HovrRideMapResources.image(named: name) {
                icon = scaleImage(img, toSize: CGSize(width: 28, height: 28))
                print("🟢 Loaded icon: \(name)")
                break
            }
        }
        
        // Fallback to programmatic icon
        if icon == nil {
            icon = createFallbackIcon()
            print("🟢 Using fallback icon")
        }
        
        let finalIcon = icon ?? createEmergencyIcon()
        print("🟢 Final icon created: \(finalIcon.size)")
        
        carIconBase = finalIcon
        let markers = CarMarkers(map: mapView, icon: themedCarIcon(finalIcon))
        print("🟢 CarMarkers instance created successfully")
        
        return markers
    }
    
    private func createFallbackIcon() -> UIImage {
        let size = CGSize(width: 28, height: 28)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.systemBlue.cgColor)
        context?.fillEllipse(in: CGRect(x: 6, y: 6, width: 16, height: 16))
        context?.setFillColor(UIColor.white.cgColor)
        context?.fillEllipse(in: CGRect(x: 10, y: 10, width: 8, height: 8))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? createEmergencyIcon()
    }
    
    private func createEmergencyIcon() -> UIImage {
        let size = CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            UIBezierPath(ovalIn: CGRect(x: 6, y: 6, width: 16, height: 16)).fill()
        }
    }
    
    private func setupMapView() {
        print("🟢 Setting up map view")
        mapView.isBuildingsEnabled = false
        mapView.isIndoorEnabled = false
        mapView.isTrafficEnabled = false
        mapView.delegate = self
        mapView.isMyLocationEnabled = true
        MapChromePolicy.apply(to: mapView)
        print("🟢 Map view setup complete")
    }
    
    private func setupLocationManager() {
        print("🟢 Setting up location manager")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        if firstFix, let location = locationManager.location {
            updateLocationOnMap(location: location)
        }
        print("🟢 Location manager setup complete")
    }
    
    private func registerChannels() {
        print("🟢 Setting up Flutter channels")
        
        reCenterChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            switch call.method {
            case "recenter-map":
                self.recenterMap(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        driversChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            if call.method == "show-drivers" {
                guard let args = call.arguments as? [String: Any],
                      let nearby = args["nearbyDrivers"] as? [[String: Any]] else {
                    print("❌ Invalid arguments for show-drivers")
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                
                let fixes = parseNearbyDrivers(raw: nearby)
                self.expectedDriverCount = fixes.count
                
                DispatchQueue.main.async {
                    print("🟢 Processing drivers on main thread...")
                    self.enqueueBatch(fixes: fixes, startAfterMs: 0)
                }
                
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func clearChannels() {
        reCenterChannel.setMethodCallHandler(nil)
        driversChannel.setMethodCallHandler(nil)
    }

    private func registerWithStack() {
        HomeViewGoogleMapIOS.instanceStackLock.lock()
        HomeViewGoogleMapIOS.instanceStack.append(self)
        registerChannels()
        HomeViewGoogleMapIOS.instanceStackLock.unlock()
    }

    private func unregisterFromStack() {
        HomeViewGoogleMapIOS.instanceStackLock.lock()
        let wasTop = HomeViewGoogleMapIOS.instanceStack.last === self
        HomeViewGoogleMapIOS.instanceStack.removeAll { $0 === self }
        if wasTop {
            clearChannels()
            HomeViewGoogleMapIOS.instanceStack.last?.registerChannels()
        }
        HomeViewGoogleMapIOS.instanceStackLock.unlock()
    }
    
    private func processPendingDriverBatches() {
        pendingBatchesLock.lock()
        defer { pendingBatchesLock.unlock() }
        
        guard !pendingDriverBatches.isEmpty else {
            print("🟢 No pending driver batches")
            return
        }
        
        print("🟢 ==================== PROCESSING PENDING BATCHES ====================")
        // print("🟢 Batch count: \(pendingDriverBatches.count)")
        
        for (index, batch) in pendingDriverBatches.enumerated() {
            // print("🟢 Processing batch \(index + 1)/\(pendingDriverBatches.count)")
            // print("🟢 Driver count: \(batch.count)")
            // print("🟢 Driver IDs: \(batch.map { $0.id })")
            enqueueBatch(fixes: batch, startAfterMs: Double(index) * 0.1)
        }
        
        pendingDriverBatches.removeAll()
        print("🟢 All pending batches processed")
    }
    
    private func updateLocationOnMap(location: CLLocation) {
        let position = location.coordinate
        // print("🟢 Location update: \(position.latitude), \(position.longitude)")
        
        if firstFix {
            // print("🟢 First location fix - centering map")
            mapView.animate(to: GMSCameraPosition.camera(withTarget: position, zoom: 16.5))
            mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            firstFix = false
            
            // Check for pending batches after first location
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.processPendingDriverBatches()
            }
        }
    }
    
    private func recenterMap(result: @escaping FlutterResult) {
        guard performRecenter() else {
            result(FlutterError(code: "LOCATION_ERROR", message: "Unable to get current location", details: nil))
            return
        }
        result(nil)
    }
    
    @discardableResult
    private func performRecenter() -> Bool {
        guard let location = locationManager.location else {
            print("⚠️ Recenter requested but current location is unavailable")
            return false
        }
        mapView.animate(to: GMSCameraPosition.camera(withTarget: location.coordinate, zoom: 16.5))
        return true
    }
    
    // The home map is a UIKit platform view, so it cannot observe the
    // SwiftUI @Published flag implicitly. iOS sends "recenter-map" over
    // com.hovr/global_channel, which flips RecenterMapController.shared.shouldRecenter.
    // Subscribe to it here so the home map actually recenters.
    private func observeRecenterFlag() {
        RecenterMapController.shared.$shouldRecenter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldRecenter in
                guard let self = self, shouldRecenter else { return }
                self.performRecenter()
                RecenterMapController.shared.shouldRecenter = false
            }
            .store(in: &cancellables)
    }
    
    // ============================================================
    // MARK: Drainer System
    // ============================================================
    
    private func setOneShotDrain(after seconds: TimeInterval) {
        drainSrc?.cancel()
        drainSrc = nil
        let s = DispatchSource.makeTimerSource(queue: .main)
        s.schedule(deadline: .now() + seconds, repeating: .never, leeway: .milliseconds(5))
        s.setEventHandler { [weak self] in
            self?.drainBatch()
        }
        s.resume()
        drainSrc = s
    }
    
    private func ensureDrainerRunning() {
        guard drainSrc == nil else { return }
        setOneShotDrain(after: max(pendingStartDelayMs, Self.MIN_TICK_MS))
    }
    
    private func pickAllowedDrivers() -> Set<String> {
        var ids = inbox.keys.shuffled()
        if ids.count > Self.MAX_ACTIVE_DRIVERS {
            ids = Array(ids.prefix(Self.MAX_ACTIVE_DRIVERS))
        }
        return Set(ids)
    }
    
    private func enqueueBatch(fixes: [CarFix], startAfterMs: TimeInterval = 0) {
        // print("🟢 ==================== ENQUEUE BATCH ====================")
        // print("🟢 Fixes count: \(fixes.count)")
        // print("🟢 Driver IDs: \(fixes.map { $0.id })")
        // print("🟢 CarMarkers exists: \(carMarkers != nil)")
        
        var added = false
        var skipped = 0
        var activeCount = 0
        
        for fix in fixes {
            var queue = inbox[fix.id] ?? []
            activeCount += queue.isEmpty ? 0 : 1
            
            if queue.count >= Self.MAX_QUEUE_PER_DRIVER {
                skipped += 1
                print("⚠️ Queue full for driver: \(fix.id)")
                continue
            }
            
            queue.append(fix)
            inbox[fix.id] = queue
            driversShownIds.insert(fix.id)
            added = true
            print("🟢 Added driver to queue: \(fix.id)")
        }
        
        actualDriverCount = driversShownIds.count
        
        // print("🟢 Enqueue summary:")
        // print("   - Expected: \(expectedDriverCount)")
        // print("   - Actual: \(actualDriverCount)")
        // print("   - Skipped: \(skipped)")
        // print("   - Active queues: \(activeCount)")
        // print("   - Total inbox keys: \(inbox.keys.count)")
        
        if added {
            print("🟢 Starting drainer...")
            pendingStartDelayMs = max(pendingStartDelayMs, startAfterMs)
            ensureDrainerRunning()
        } else {
            print("⚠️ No fixes added")
        }
    }
    
    private func drainBatch() {
        lastDrainFiredAt = CACurrentMediaTime()
        // print("🔵 DRAIN BATCH - Time: \(Date())")
        // print("🔵 Inbox keys: \(inbox.keys.sorted())")
        
        var batch: [CarFix] = []
        let allowed = pickAllowedDrivers()
        
        // print("🔵 Allowed drivers: \(allowed)")
        
        for (id, _) in inbox where allowed.contains(id) {
            guard var queue = inbox[id], !queue.isEmpty else { continue }
            let cur = queue.removeFirst()
            inbox[id] = queue
            
            // Feed fixes directly — arcifySegment injected synthetic headings that
            // caused unstable rotation compared to Android's direct upsert path.
            batch.append(cur)
        }
        
        if !batch.isEmpty {
            // print("🔵 Upserting \(batch.count) markers")
            // print("🔵 Marker IDs: \(batch.map { $0.id })")
            refreshCarIconIfThemeChanged()
            carMarkers.upsert(fixes: batch, nowMs: CACurrentMediaTime())
            
            let interval = drainIntervalMs
            
            setOneShotDrain(after: interval)
        } else {
            print("🔵 No batch to drain, stopping")
            drainSrc?.cancel()
            drainSrc = nil
        }
    }
    
    func pauseBuffer() {
        bufferPaused = true
        drainSrc?.cancel()
        drainSrc = nil
    }
    
    func resumeBuffer(startAfterMs: TimeInterval = 0) {
        bufferPaused = false
        pendingStartDelayMs = max(pendingStartDelayMs, startAfterMs)
        drainSrc?.cancel()
        drainSrc = nil
        ensureDrainerRunning()
    }
    
    func setDrainInterval(ms: TimeInterval) {
        let sec = max(ms / 1000.0, 0.05)
        drainIntervalMs = sec
    }
    
    /// Car marker in the app theme's accent colour (light/dark/festive).
    private func themedCarIcon(_ base: UIImage) -> UIImage {
        let tint = MapThemeColors.current.accent
        carIconTint = tint
        carIconFestiveVersion = HovrFestiveCar.version
        // Festive artwork keeps its own colours and its tall shape.
        if let festive = HovrFestiveCar.icon(length: 28) { return festive }
        return HovrCarIconTint.tinted(base, tint: tint)
    }

    /// Theme changes arrive between driver updates, so recolour on the next batch.
    private func refreshCarIconIfThemeChanged() {
        guard let base = carIconBase,
              MapThemeColors.current.accent != carIconTint || HovrFestiveCar.version != carIconFestiveVersion
        else { return }
        carMarkers.setIcon(themedCarIcon(base))
    }

    private func scaleImage(_ image: UIImage, toSize size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out ?? image
    }
    
    deinit {
        print("🔴 HomeViewGoogleMapIOS deinit")
        unregisterFromStack()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        drainSrc?.cancel()
        drainSrc = nil
        inbox.removeAll()
        pendingDriverBatches.removeAll()
        driversShownIds.removeAll()
    }
}

// ================================================================
// MARK: - Delegates
// ================================================================

extension HomeViewGoogleMapIOS: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        // Keep firstFix as is
        firstFix = false
    }

    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        true
    }

    func mapView(
        _ mapView: GMSMapView,
        didTapPOIWithPlaceID placeID: String,
        name: String,
        location: CLLocationCoordinate2D
    ) -> Bool {
        true
    }
}

extension HomeViewGoogleMapIOS: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        updateLocationOnMap(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
}
