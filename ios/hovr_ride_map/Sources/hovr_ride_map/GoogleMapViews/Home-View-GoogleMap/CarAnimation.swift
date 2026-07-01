//
//  CarAnimation.swift
//  HOVR
//
//  Created by Bipan Sharma on 06/10/25.
//

//import UIKit
//import QuartzCore
//
//class CarAnimation {
//    private var displayLink: CADisplayLink?
//    private let duration: TimeInterval
//    private var startTime: CFTimeInterval?
//    private let updateBlock: (Double) -> Void
//    var onComplete: (() -> Void)?
//    
//    init(duration: TimeInterval, updateBlock: @escaping (Double) -> Void) {
//        self.duration = duration
//        self.updateBlock = updateBlock
//    }
//    
//    func start() {
//        startTime = CACurrentMediaTime()
//        displayLink = CADisplayLink(target: self, selector: #selector(update))
//        displayLink?.add(to: .main, forMode: .common)
//    }
//    
//    func cancel() {
//        displayLink?.invalidate()
//        displayLink = nil
//    }
//    
//    @objc private func update() {
//        guard let startTime = startTime else { return }
//        
//        let elapsed = CACurrentMediaTime() - startTime
//        let progress = min(elapsed / duration, 1.0)
//        
//        updateBlock(progress)
//        
//        if progress >= 1.0 {
//            cancel()
//            onComplete?()
//        }
//    }
//}


final class CarAnimation {
    private var displayLink: CADisplayLink?
    private let duration: TimeInterval
    private var startTime: CFTimeInterval?
    private let updateBlock: (Double) -> Void
    var onComplete: (() -> Void)?
    
    
    init(duration: TimeInterval, updateBlock: @escaping (Double) -> Void) {
        self.duration = duration
        self.updateBlock = updateBlock
    }
    func start() {
        startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(update))
        // Keep it running during scroll/gestures
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
    }
    @objc private func update() {
        guard let startTime = startTime else { return }
        let elapsed = CACurrentMediaTime() - startTime
        
//        let progress = min(max(elapsed / duration, 0.0), 1.0)
        let linear = min(max(elapsed / duration, 0.0), 1.0)
        let progress = linear * linear * (3 - 2 * linear)  // smoothstep ease

        updateBlock(progress)
        if progress >= 1.0 {
            cancel()
            onComplete?()
        }
    }
}
