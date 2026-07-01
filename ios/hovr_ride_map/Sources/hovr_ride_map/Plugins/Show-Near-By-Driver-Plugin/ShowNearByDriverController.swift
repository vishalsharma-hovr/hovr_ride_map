//
//  ShowNearByDriverController.swift
//  HOVR
//
//  Created by Vishal Sharma on 11/08/25.
//


import CoreLocation

class ShowNearByDriverController: ObservableObject {
    static let shared = ShowNearByDriverController()
    
    @Published var coordinates: [CLLocationCoordinate2D] = []
    
    private func doubleValue(from any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }
    
    func updateDriverLocations(drivers: [[String: Any]]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var rawCoordinates: [CLLocationCoordinate2D] = []
            rawCoordinates.reserveCapacity(drivers.count)
            
                // First, extract all raw coordinates
            for driver in drivers {
                guard
//                    let driverid = driver["driver_id"] as? String,
                    let location = driver["position"] as? [String: Any],
                    let lat = self.doubleValue(from: location["latitude"]),
                    let lng = self.doubleValue(from: location["longitude"]),
                    lat != 0.0, lng != 0.0
                else { continue }
                
                rawCoordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            
                // Immediately publish raw coordinates for instant marker placement
            self.coordinates = rawCoordinates
            
                // Then snap all coordinates to roads and update
            self.snapCoordinatesToRoads(rawCoordinates)
        }
    }
    
    private func snapCoordinatesToRoads(_ rawCoordinates: [CLLocationCoordinate2D]) {
        guard !rawCoordinates.isEmpty else { return }
        
            // Process coordinates in batches to respect API limits
        let batchSize = 10 // Process 10 drivers at a time
        let batches = rawCoordinates.chunked(into: batchSize)
        
        var snappedResults: [CLLocationCoordinate2D] = []
        let dispatchGroup = DispatchGroup()
        
        for (batchIndex, batch) in batches.enumerated() {
            dispatchGroup.enter()
            
                // Create coordinate pairs for each driver (current + forward point for bearing)
            let coordinatePairs = batch.map { coord in
                let forwardPoint = CLLocationCoordinate2D(
                    latitude: coord.latitude + 0.0001,
                    longitude: coord.longitude
                )
                return [coord, forwardPoint]
            }
            
                // Snap each pair
            snapBatchToRoads(coordinatePairs: coordinatePairs) { [weak self] batchResults in
                DispatchQueue.main.async {
                        // Store results in correct order
                    if snappedResults.count == batchIndex * batchSize {
                        snappedResults.append(contentsOf: batchResults)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
            // Update coordinates when all batches are complete
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
                // Only update if we got meaningful results
            if !snappedResults.isEmpty && snappedResults.count == rawCoordinates.count {
                self.coordinates = snappedResults
            }
            // If snapping failed, keep the raw coordinates already published
        }
    }
    
    private func snapBatchToRoads(coordinatePairs: [[CLLocationCoordinate2D]], completion: @escaping ([CLLocationCoordinate2D]) -> Void) {
        var results: [CLLocationCoordinate2D] = []
        let group = DispatchGroup()
        
        for pair in coordinatePairs {
            group.enter()
                // Remove the interpolate parameter since your function doesn't support it
            snapPathToRoads(coordinates: pair) { snappedPath in
                let snappedCoordinate = snappedPath.first ?? pair.first ?? CLLocationCoordinate2D()
                results.append(snappedCoordinate)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.coordinates.removeAll()
        }
    }
}

    // Helper extension for chunking arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
