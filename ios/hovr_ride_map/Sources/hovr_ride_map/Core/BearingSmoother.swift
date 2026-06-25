import Foundation

/// Exponential moving average for map marker headings — mirrors Android `BearingSmoother`.
struct BearingSmoother {
    private let alpha: Float
    private var hasValue = false
    private var last: Float = 0

    init(alpha: Float = 0.35) {
        self.alpha = alpha
    }

    mutating func reset() {
        hasValue = false
    }

    mutating func apply(_ target: Float) -> Float {
        let normalized = normalize360(target)
        guard hasValue else {
            last = normalized
            hasValue = true
            return last
        }
        last = normalize360(last + normalizeDelta(normalized - last) * alpha)
        return last
    }
}
