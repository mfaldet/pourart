import SwiftUI
import MetalKit

struct CanvasView: UIViewRepresentable {

    @ObservedObject var motion: MotionService
    @Binding var debugMode: UInt32
    var onFPS: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(motion: motion, debugMode: $debugMode, onFPS: onFPS)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0.97, 0.97, 0.97, 1)
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60

        context.coordinator.setupRenderer(view: view)
        context.coordinator.setupGestures(view: view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.renderer?.debugMode = debugMode
    }

    @MainActor
    final class Coordinator: NSObject {

        let device: MTLDevice
        var renderer: Renderer?
        private let motion: MotionService
        @Binding var debugMode: UInt32
        private let onFPS: (Double) -> Void

        // Grid dimensions must match FluidSimulator
        private let gridW = 256
        private let gridH = 576

        init(motion: MotionService, debugMode: Binding<UInt32>, onFPS: @escaping (Double) -> Void) {
            self.device    = MTLCreateSystemDefaultDevice()!
            self.motion    = motion
            self._debugMode = debugMode
            self.onFPS     = onFPS
        }

        func setupRenderer(view: MTKView) {
            do {
                let sim = try FluidSimulator(device: device, width: gridW, height: gridH)
                let r   = try Renderer(sim: sim, view: view)
                r.onFPS = onFPS
                renderer = r
                view.delegate = r
                motion.start()
            } catch {
                print("Renderer init failed: \(error)")
            }
        }

        func setupGestures(view: MTKView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            let long = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            long.minimumPressDuration = 0
            view.addGestureRecognizer(pan)
            view.addGestureRecognizer(long)
        }

        @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
            guard let view = gr.view else { return }
            switch gr.state {
            case .began, .changed:
                let pt = gr.location(in: view)
                let norm = SIMD2<Float>(Float(pt.x / view.bounds.width),
                                       Float(pt.y / view.bounds.height))
                // Map screen-space Y to grid-space (Y flips in Metal)
                renderer?.pourPos = SIMD2<Float>(norm.x, 1 - norm.y)
                updateGravity(view: view)
            default:
                renderer?.pourPos = nil
            }
        }

        @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
            guard let view = gr.view else { return }
            switch gr.state {
            case .changed:
                let pt = gr.location(in: view)
                let norm = SIMD2<Float>(Float(pt.x / view.bounds.width),
                                       Float(pt.y / view.bounds.height))
                renderer?.pourPos = SIMD2<Float>(norm.x, 1 - norm.y)
                updateGravity(view: view)
            default:
                renderer?.pourPos = nil
            }
        }

        private func updateGravity(view: UIView) {
            renderer?.gravity = motion.gravity
        }
    }
}
