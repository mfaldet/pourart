import SwiftUI
import CoreMotion
import Combine

// ---------------------------------------------------------------------------
// BalanceTestView — a tiny tilt-driven mini-game used to confirm gravity
// updates are reaching the canvas continuously. Tap anywhere to spawn a
// 3D-shaded ball. Tilt the phone and the ball rolls in the direction of
// gravity, bouncing off the screen edges. A ~3° deadband keeps the ball
// still when the phone is essentially flat.
// ---------------------------------------------------------------------------
struct BalanceTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var motion = BallMotion()

    @State private var ball:      Ball? = nil
    @State private var lastTick:  CFTimeInterval = 0

    private let ballRadius: CGFloat = 18
    private let tickRate              = 1.0 / 60.0
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(white: 0.08).ignoresSafeArea()

                // Subtle inner border to make the "table" feel like an arena
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
                    .padding(8)

                // Instructions when no ball is placed
                if ball == nil {
                    VStack(spacing: 8) {
                        Text("Tilt Test")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Tap anywhere to spawn a ball.\nTilt the phone to roll it around.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                }

                // The ball itself — 3D radial gradient + drop shadow
                if let ball {
                    ball3D
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .position(ball.position)
                }

                // Top-right close button
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                ball = Ball(position: location, velocity: .zero)
            }
            .onReceive(timer) { _ in
                tick(geoSize: geo.size)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    // 3D-style red marble
    private var ball3D: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.85, blue: 0.85),   // bright top-left highlight
                        Color(red: 0.95, green: 0.20, blue: 0.20),
                        Color(red: 0.55, green: 0.05, blue: 0.05),   // dark bottom-right
                        Color(red: 0.25, green: 0.02, blue: 0.02),
                    ],
                    center: UnitPoint(x: 0.30, y: 0.30),
                    startRadius: 0,
                    endRadius: ballRadius * 1.4
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.35), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.55), radius: 4, x: 2, y: 5)
    }

    // MARK: - Physics

    private func tick(geoSize: CGSize) {
        guard var b = ball else { return }
        let dt: CGFloat = CGFloat(tickRate)

        // Acceleration from gravity vector (already deadbanded by BallMotion).
        let accelScale: CGFloat = 1800        // points / s² per unit gravity
        let ax = CGFloat(motion.gravity.x) * accelScale
        let ay = CGFloat(motion.gravity.y) * accelScale

        b.velocity.dx += ax * dt
        b.velocity.dy += ay * dt

        // Mild rolling-friction so the ball comes to rest on a flat surface.
        b.velocity.dx *= 0.985
        b.velocity.dy *= 0.985

        // If gravity is in the deadband AND the ball is slow, stop it.
        if motion.gravity == .zero && hypot(b.velocity.dx, b.velocity.dy) < 6 {
            b.velocity = .zero
        }

        // Step position
        b.position.x += b.velocity.dx * dt
        b.position.y += b.velocity.dy * dt

        // Bounce off the four walls (screen edges)
        let r = ballRadius
        if b.position.x < r {
            b.position.x = r
            b.velocity.dx = -b.velocity.dx * 0.55
        }
        if b.position.x > geoSize.width - r {
            b.position.x = geoSize.width - r
            b.velocity.dx = -b.velocity.dx * 0.55
        }
        if b.position.y < r {
            b.position.y = r
            b.velocity.dy = -b.velocity.dy * 0.55
        }
        if b.position.y > geoSize.height - r {
            b.position.y = geoSize.height - r
            b.velocity.dy = -b.velocity.dy * 0.55
        }

        ball = b
    }
}

private struct Ball {
    var position: CGPoint
    var velocity: CGVector
}

// ---------------------------------------------------------------------------
// BallMotion — same idea as MotionService but with a *smaller* deadband
// (~3°) so the ball moves on slight tilts, which is the whole point of the
// balance test. Sits in its own class so the canvas's MotionService isn't
// affected by this view.
// ---------------------------------------------------------------------------
@MainActor
final class BallMotion: ObservableObject {
    @Published var gravity: SIMD2<Float> = .zero

    private let manager  = CMMotionManager()
    private let queue    = OperationQueue()
    private let deadband: Float = 0.05   // ~3° tilt

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let gx = Float(motion.gravity.x)
            let gy = Float(-motion.gravity.y)
            let mag = sqrt(gx * gx + gy * gy)
            let result: SIMD2<Float> = (mag < self.deadband) ? .zero : SIMD2(gx, gy)
            Task { @MainActor in self.gravity = result }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
