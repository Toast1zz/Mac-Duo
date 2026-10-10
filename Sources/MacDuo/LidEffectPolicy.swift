import Foundation

struct LidMotionIntent {
    private(set) var lastMovedDownTime: TimeInterval = -Double.greatestFiniteMagnitude

    mutating func update(
        angularVelocity: Double,
        at now: TimeInterval,
        closingSpeed: Double,
        openingSpeed: Double
    ) {
        if angularVelocity >= openingSpeed {
            // Opening is an intentional reversal, so an earlier close must not
            // be reused to start the effect again near the threshold.
            lastMovedDownTime = -Double.greatestFiniteMagnitude
        } else if angularVelocity <= -closingSpeed {
            lastMovedDownTime = now
        }
    }

    func wasClosingRecently(at now: TimeInterval, memoryDuration: TimeInterval) -> Bool {
        now - lastMovedDownTime < memoryDuration
    }

    mutating func reset() {
        lastMovedDownTime = -Double.greatestFiniteMagnitude
    }
}

/// How long the lid has stayed opened back above the start angle.
struct LidOpenDwell {
    private(set) var since: TimeInterval?

    mutating func update(angle: Double, at now: TimeInterval, dwellAngle: Double) {
        if angle >= dwellAngle {
            if since == nil { since = now }
        } else {
            since = nil
        }
    }

    func hasDwelled(at now: TimeInterval, duration: TimeInterval) -> Bool {
        guard let since else { return false }
        return now - since >= duration
    }

    mutating func reset() {
        since = nil
    }
}

/// Whether a new run may start. A run that ends disarms it, and the lid has
/// to open clearly past the start angle, or rest at it, before the next run.
/// Without this, rocking the lid around the start angle replays the whole
/// effect: opening across it ends a run and closing back starts another.
struct LidRearm {
    private(set) var isArmed = false
    private var aboveSince: TimeInterval?

    /// Degrees past the start angle that re-arm at once.
    static let margin: Double = 3

    /// How long the lid has to rest at or above the start angle instead, for
    /// a start angle near the hinge limit.
    static let dwell: TimeInterval = 0.4

    mutating func update(angle: Double, threshold: Double, at now: TimeInterval) {
        guard !isArmed else { return }
        guard angle >= threshold else {
            aboveSince = nil
            return
        }
        if angle >= threshold + Self.margin {
            isArmed = true
            return
        }
        if let aboveSince {
            if now - aboveSince >= Self.dwell { isArmed = true }
        } else {
            aboveSince = now
        }
    }

    mutating func disarm() {
        isArmed = false
        aboveSince = nil
    }
}

/// Tells a moving lid from sensor jitter. A resting lid can wander by a tenth
/// of a degree, and over a short poll interval that reads as several degrees
/// per second.
struct LidMotion {
    /// Changes smaller than this, in degrees, are noise.
    static let deadband: Double = 0.25

    private(set) var anchor: Double?
    private(set) var anchorTime: TimeInterval = 0

    /// Returns the speed in degrees per second when the angle has moved past
    /// the deadband since the last movement, and `nil` otherwise.
    mutating func update(angle: Double, at now: TimeInterval) -> Double? {
        guard let anchor else {
            self.anchor = angle
            anchorTime = now
            return nil
        }
        guard abs(angle - anchor) >= Self.deadband else { return nil }
        let dt = now - anchorTime
        self.anchor = angle
        anchorTime = now
        guard dt > 0.001 else { return nil }
        return (angle - anchor) / dt
    }

    mutating func reset() {
        anchor = nil
        anchorTime = 0
    }
}

struct LidEffectPolicy {
    let threshold: Double
    let hysteresis: Double

    /// A lid held at or above this angle has been opened again, even when
    /// threshold + hysteresis is past what the hinge can reach. The threshold
    /// itself, so a hinge whose limit rounds to the threshold still releases.
    var dwellAngle: Double { threshold }

    /// How far the lid must have risen above its lowest reading of the run
    /// before opening speed alone releases the effect. A sensor that reports
    /// whole degrees moves in 1° steps, and one step over a sensor refresh
    /// already reads as fast opening. A lid resting on a half-degree boundary
    /// alternates between two readings, and this keeps that from flapping the
    /// effect on and off.
    static let minimumReleaseRise: Double = 1.5

    func wantsEffect(
        isEnabled: Bool,
        isActive: Bool,
        angle: Double,
        predictedAngle: Double,
        riseSinceLowest: Double,
        hasBeenAboveThreshold: Bool,
        isArmed: Bool = true,
        wasClosingRecently: Bool,
        isClearlyOpening: Bool,
        hasDwelledOpen: Bool,
        minimumDurationElapsed: Bool
    ) -> Bool {
        guard isEnabled else { return false }

        if isActive {
            // Deliberately opening back across the configured start angle is
            // sufficient to recover even when threshold + hysteresis cannot
            // be reached by the hardware. The rise rules out a single
            // whole-degree step; a smaller opening releases through the dwell.
            if isClearlyOpening, angle >= threshold, riseSinceLowest >= Self.minimumReleaseRise {
                return false
            }

            // An opening slower than that still ends with the lid held above
            // the start angle, which releases it too.
            if hasDwelledOpen { return false }

            // Keep the ordinary release hysteresis for stationary readings and
            // sensor jitter around the start angle.
            guard minimumDurationElapsed else { return true }
            return angle < threshold + hysteresis
        }

        // A resting or opening lid below the threshold must not start the
        // effect, including while an older closing observation is remembered.
        return hasBeenAboveThreshold
            && isArmed
            && wasClosingRecently
            && !isClearlyOpening
            && predictedAngle <= threshold
    }
}
