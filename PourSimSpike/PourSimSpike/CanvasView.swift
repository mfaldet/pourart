import SwiftUI
import MetalKit

// TouchMTKView overrides UIView touch delivery directly so we can track every
// simultaneous finger independently. UIGestureRecognizer only exposes one
// location at a time; UITouch gives the full set.
final class TouchMTKView: MTKView {

    var onTouchesChanged: (([SIMD2<Float>]) -> Void)?

    override init(frame: CGRect, device: (any MTLDevice)?) {
        super.init(frame: frame, device: device)
        isMultipleTouchEnabled = true
    }

    required init(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        report(event)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        report(event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        report(event)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouchesChanged?([])
    }

    private func report(_ event: UIEvent?) {
        guard let all = event?.allTouches else { onTouchesChanged?([]); return }
        let active = all.filter { $0.phase != .ended && $0.phase != .cancelled }
        let positions = active.map { touch -> SIMD2<Float> in
            let pt = touch.location(in: self)
            // Screen-space Y is top-down; Metal/grid Y is bottom-up — flip.
            return SIMD2<Float>(Float(pt.x / bounds.width),
                                1.0 - Float(pt.y / bounds.height))
        }
        onTouchesChanged?(positions)
    }
}

struct CanvasView: UIViewRepresentable {

    @ObservedObject var motion: MotionService
    @Binding var debugMode: UInt32
    var injectColor: SIMD3<Float>       // plain value — owned by PaletteStore
    @Binding var activeTool: Tool
    var onFPS: (Double) -> Void
    var onRendererReady: ((Renderer) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(motion: motion, debugMode: $debugMode, activeTool: $activeTool, onFPS: onFPS)
    }

    func makeUIView(context: Context) -> TouchMTKView {
        let view = TouchMTKView(frame: .zero, device: context.coordinator.device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0.97, 0.97, 0.97, 1)
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60

        context.coordinator.setupRenderer(view: view, onRendererReady: onRendererReady)

        view.onTouchesChanged = { [weak coord = context.coordinator] positions in
            coord?.renderer?.pourPositions = positions
            coord?.renderer?.gravity = coord?.motion.gravity ?? .zero
        }

        return view
    }

    func updateUIView(_ view: TouchMTKView, context: Context) {
        context.coordinator.renderer?.debugMode   = debugMode
        context.coordinator.renderer?.injectColor = injectColor
        context.coordinator.renderer?.activeTool  = activeTool
    }

    @MainActor
    final class Coordinator: NSObject {

        let device: MTLDevice
        var renderer: Renderer?
        let motion: MotionService
        @Binding var debugMode: UInt32
        @Binding var activeTool: Tool
        private let onFPS: (Double) -> Void

        private let gridW = 256
        private let gridH = 576

        init(motion: MotionService,
             debugMode: Binding<UInt32>,
             activeTool: Binding<Tool>,
             onFPS: @escaping (Double) -> Void) {
            self.device      = MTLCreateSystemDefaultDevice()!
            self.motion      = motion
            self._debugMode  = debugMode
            self._activeTool = activeTool
            self.onFPS       = onFPS
        }

        func setupRenderer(view: MTKView, onRendererReady: ((Renderer) -> Void)?) {
            do {
                let sim = try FluidSimulator(device: device, width: gridW, height: gridH)
                let r   = try Renderer(sim: sim, view: view)
                r.onFPS = onFPS
                renderer = r
                view.delegate = r
                motion.start()
                onRendererReady?(r)
            } catch {
                print("Renderer init failed: \(error)")
            }
        }
    }
}
