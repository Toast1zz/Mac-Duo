import LidAngleKit
import Testing
@testable import MacDuo

struct LidMotionTests {

    @Test
    func testShutLidThatWrapsAroundReadsAsShut() {
        #expect(LidAngleSensor.normalized(359.9) == 0)
        #expect(LidAngleSensor.normalized(360) == 0)
        #expect(LidAngleSensor.normalized(0.4) == 0.4)
        #expect(LidAngleSensor.normalized(135) == 135)
    }

    @Test
    func testJitterIsNotMovement() {
        var motion = LidMotion()
        #expect(motion.update(angle: 110.00, at: 0) == nil)
        #expect(motion.update(angle: 110.10, at: 0.1) == nil)
        #expect(motion.update(angle: 109.92, at: 0.2) == nil)
        #expect(motion.update(angle: 110.05, at: 0.3) == nil)
    }

    @Test
    func testSlowMovementAccumulatesPastTheDeadband() {
        var motion = LidMotion()
        _ = motion.update(angle: 110.0, at: 0)
        #expect(motion.update(angle: 109.9, at: 0.1) == nil)
        #expect(motion.update(angle: 109.8, at: 0.2) == nil)
        let speed = motion.update(angle: 109.7, at: 0.3)
        #expect(speed != nil)
        #expect(abs((speed ?? 0) + 1) < 0.001)
    }

    @Test
    func testClosingIsMovement() {
        var motion = LidMotion()
        _ = motion.update(angle: 110, at: 0)
        let speed = motion.update(angle: 104, at: 0.1)
        #expect(abs((speed ?? 0) + 60) < 0.001)
    }

    @Test
    func testEndedRunWaitsForTheLidToOpenClearly() {
        var rearm = LidRearm()
        rearm.update(angle: 95, threshold: 90, at: 0)
        #expect(rearm.isArmed)

        rearm.disarm()
        // Opening just past the start angle, then closing again, is a rock
        // around the angle and must not start another run.
        rearm.update(angle: 91, threshold: 90, at: 1.0)
        rearm.update(angle: 92, threshold: 90, at: 1.1)
        rearm.update(angle: 89, threshold: 90, at: 1.2)
        #expect(!rearm.isArmed)

        rearm.update(angle: 93, threshold: 90, at: 1.3)
        #expect(rearm.isArmed)
    }

    @Test
    func testRestingAtTheStartAngleRearms() {
        var rearm = LidRearm()
        // A start angle at the hinge limit cannot be passed by the margin.
        rearm.update(angle: 130, threshold: 130, at: 0)
        rearm.update(angle: 130.5, threshold: 130, at: 0.2)
        #expect(!rearm.isArmed)
        rearm.update(angle: 130.2, threshold: 130, at: 0.41)
        #expect(rearm.isArmed)
    }

    @Test
    func testDisarmedPolicyDoesNotStart() {
        let policy = LidEffectPolicy(threshold: 90, hysteresis: 4)
        func starts(armed: Bool) -> Bool {
            policy.wantsEffect(
                isEnabled: true,
                isActive: false,
                angle: 89,
                predictedAngle: 89,
                riseSinceLowest: 0,
                hasBeenAboveThreshold: true,
                isArmed: armed,
                wasClosingRecently: true,
                isClearlyOpening: false,
                hasDwelledOpen: false,
                minimumDurationElapsed: true
            )
        }
        #expect(starts(armed: true))
        #expect(!starts(armed: false))
    }
}
