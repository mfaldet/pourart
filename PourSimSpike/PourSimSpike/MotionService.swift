import CoreMotion
import Combine

@MainActor
final class MotionService: ObservableObject {

    @Published var gravity: SIMD2<Float> = .zero

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    // Gravity strength multiplier — tune during spike testing
    private let gravityScale: Float = 15.0

    // Simple exponential smoothing to reduce accelerometer jitter
    private var smoothed: SIMD2<Float> = .zero
    private let smoothing: Float = 0.85

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let raw = SIMD2<Float>(Float(motion.gravity.x), Float(-motion.gravity.y))
            let s = self.smoothing
            let next = s * self.smoothed + (1 - s) * raw * self.gravityScale
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
