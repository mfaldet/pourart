import SwiftUI
import MetalKit

// TouchMTKView overrides UIView touch delivery directly so we can track every
// simultaneous finger independently. UIGestureRecognizer only exposes one
// location at a time; UITouch gives the full set.
final class TouchMTKView: MTKView {

    var onTouchesChanged: (([PourTouch]) -> Void)?

    // Pressure → pour radius mapping.
    // Light touch = pinprick · normal touch = small stream · hard press = wide pour.
    // 10× smaller than previous (was 1.0…40) — full-finger press is now a
    // ~4-cell radius bottle-stream, light tap is a single cell.
    private let minPourRadius: Float = 0.1
    private let maxPourRadius: Float = 4.0

    // Previous UV position per touch — used to compute drag vectors for
    // swipe/stir tools.
    private var lastUV: [ObjectIdentifier: SIMD2<Float>] = [:]

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
        for t in touches { lastUV.removeValue(forKey: ObjectIdentifier(t)) }
        report(event)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastUV.removeAll()
        onTouchesChanged?([])
    }

    private func report(_ event: UIEvent?) {
        guard let all = event?.allTouches else { onTouchesChanged?([]); return }
        let active = all.filter { $0.phase != .ended && $0.phase != .cancelled }

        // Capture every sub-frame sample iOS recorded (ProMotion samples at
        // up to 240Hz internally) so fast drags stay continuous, not dotted.
        var result: [PourTouch] = []
        result.reserveCapacity(active.count * 4)
        for touch in active {
            let id      = ObjectIdentifier(touch)
            let samples = event?.coalescedTouches(for: touch) ?? [touch]
            var prevUV  = lastUV[id]
            for s in samples {
                let pt  = s.location(in: self)
                let pos = SIMD2<Float>(Float(pt.x / bounds.width),
                                       Float(pt.y / bounds.height))
                let drag: SIMD2<Float>
                if let prev = prevUV { drag = pos - prev }
                else                 { drag = .zero }
                result.append(PourTouch(pos: pos, radius: radius(for: s), drag: drag))
                prevUV = pos
            }
            lastUV[id] = prevUV
        }
        onTouchesChanged?(result)
    }

    // Touch pressure → pour radius. Prefers `force` (Apple Pencil & older
    // 3D-Touch iPhones), falls back to contact-area (`majorRadius`) which
    // every iPhone reports — light tap ≈ 5pt, hard press ≈ 20pt+.
    private func radius(for touch: UITouch) -> Float {
        var pressure: Float = 0

        if touch.maximumPossibleForce > 0 {
            let normalized = Float(touch.force / touch.maximumPossibleForce)
            if normalized > 0.001 { pressure = normalized }
        }

        if pressure == 0 {
            let area = Float(touch.majorRadius)
            // Empirical: 1pt = barely touching, 4pt = light, 10pt = normal, 20pt = hard.
            pressure = Swift.max(0, Swift.min(1, (area - 1) / 19))
        }

        // Curve that *damps* the low end so a gentle touch stays gentle.
        // pow(p, 1.7) keeps light taps ~3 cells, normal touches ~13 cells,
        // hard presses at the full ~40-cell maximum.
        let curved = pow(pressure, 1.7)
        return minPourRadius + (maxPourRadius - minPourRadius) * curved
    }
}

struct PourTouch {
    let pos:    SIMD2<Float>
    let radius: Float
    /// Per-frame drag vector in UV space — used by Swipe/Stir to push paint.
    let drag:   SIMD2<Float>
}

struct CanvasView: UIViewRepresentable {

    @ObservedObject var motion: MotionService
    var injectColor: SIMD3<Float>       // plain value — owned by PaletteStore
    @Binding var activeTool: Tool
    var onFPS: (Double) -> Void
    var onRendererReady: ((Renderer) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(motion: motion, activeTool: $activeTool, onFPS: onFPS)
    }

    func makeUIView(context: Context) -> TouchMTKView {
        let view = TouchMTKView(frame: .zero, device: context.coordinator.device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0.97, 0.97, 0.97, 1)
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60

        context.coordinator.setupRenderer(view: view, onRendererReady: onRendererReady)

        view.onTouchesChanged = { [weak coord = context.coordinator] touches in
            coord?.renderer?.pourTouches = touches
            // gravity is now polled live from motionService in draw()
        }

        return view
    }

    func updateUIView(_ view: TouchMTKView, context: Context) {
        context.coordinator.renderer?.injectColor = injectColor
        context.coordinator.renderer?.activeTool  = activeTool
    }

    @MainActor
    final class Coordinator: NSObject {

        let device: MTLDevice
        var renderer: Renderer?
        let motion: MotionService
        @Binding var activeTool: Tool
        private let onFPS: (Double) -> Void

        private let gridW = 256
        private let gridH = 576

        init(motion: MotionService,
             activeTool: Binding<Tool>,
             onFPS: @escaping (Double) -> Void) {
            self.device      = MTLCreateSystemDefaultDevice()!
            self.motion      = motion
            self._activeTool = activeTool
            self.onFPS       = onFPS
        }

        func setupRenderer(view: MTKView, onRendererReady: ((Renderer) -> Void)?) {
            do {
                let sim = try FluidSimulator(device: device, width: gridW, height: gridH)
                let r   = try Renderer(sim: sim, view: view)
                r.onFPS         = onFPS
                r.motionService = motion          // tilt updates every frame
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
