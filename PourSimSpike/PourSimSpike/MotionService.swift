import CoreMotion
import Combine

@MainActor
final class MotionService: ObservableObject {

    @Published var gravity: SIMD2<Float> = .zero

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    private let gravityScale: Float = 60.0

    // Below ~15° tilt we treat the phone as flat. Real acrylic paint has
    // enough static friction that it just doesn't move on a level surface.
    // sin(15°) ≈ 0.259 of full gravity.
    private let tiltDeadzone: Float = 0.26

    // Simple exponential smoothing to reduce accelerometer jitter
    private var smoothed: SIMD2<Float> = .zero
    private let smoothing: Float = 0.75

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let raw = SIMD2<Float>(Float(motion.gravity.x), Float(-motion.gravity.y))
            let mag = sqrt(raw.x * raw.x + raw.y * raw.y)

            let scaled: SIMD2<Float>
            if mag < self.tiltDeadzone {
                // Phone flat-ish — kill gravity entirely so paint can settle.
                scaled = .zero
            } else {
                // Smoothly ramp from the deadzone edge to full force at 90°.
                let aboveDeadzone = (mag - self.tiltDeadzone) / (1 - self.tiltDeadzone)
                scaled = raw * (self.gravityScale * aboveDeadzone / mag)
            }

            let s = self.smoothing
            let next = s * self.smoothed + (1 - s) * scaled
            Task { @MainActor in
                self.smoothed = next
                self.gravity  = next
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
