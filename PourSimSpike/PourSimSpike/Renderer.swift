import Metal
import MetalKit

@MainActor
final class Renderer: NSObject, MTKViewDelegate {

    private let sim: FluidSimulator
    private let renderPipeline: MTLRenderPipelineState

    var gravity: SIMD2<Float> = .zero
    var pourTouches: [PourTouch] = []
    var injectColor: SIMD3<Float> = SIMD3(0.8, 0.2, 0.1)
    var activeTool: Tool = .pour
    var toolRadius: Float = 14
    var toolForce: Float = 1.0

    /// Set by the Coordinator. Polled every frame in draw() so tilt is
    /// continuously responsive — paint reacts to the device orientation
    /// whether the user is touching the screen or not.
    weak var motionService: MotionService?

    private var frameCount = 0
    private var lastFPSTime = CACurrentMediaTime()
    var onFPS: ((Double) -> Void)?

    init(sim: FluidSimulator, view: MTKView) throws {
        self.sim = sim

        let lib = sim.device.makeDefaultLibrary()!
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = lib.makeFunction(name: "fullscreenVert")
        desc.fragmentFunction = lib.makeFunction(name: "renderFrag")
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        renderPipeline = try sim.device.makeRenderPipelineState(descriptor: desc)
    }

    func fillBase(rgb: SIMD3<Float>)        { sim.fillBase(rgb: rgb) }
    func applyConsistency(_ value: Float)  { sim.applyConsistency(value) }
    func applyCanvasShape(_ s: CanvasShape) { sim.applyCanvasShape(s) }

    private(set) var drawableSize: CGSize = .zero

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = size
    }

    // Render the current sim state to a UIImage at drawable resolution.
    // Uses an off-screen .shared texture so the CPU can read the bytes back.
    // Blocks until the GPU completes — call only once per "Finish" tap.
    func captureImage() -> UIImage? {
        let width  = Int(drawableSize.width)
        let height = Int(drawableSize.height)
        guard width > 0, height > 0 else { return nil }

        let texDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        texDesc.usage       = [.renderTarget]
        texDesc.storageMode = .shared   // CPU-readable
        guard let tex    = sim.device.makeTexture(descriptor: texDesc),
              let cmdBuf = sim.commandQueue.makeCommandBuffer()
        else { return nil }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture     = tex
        passDesc.colorAttachments[0].loadAction  = .clear
        passDesc.colorAttachments[0].storeAction = .store
        passDesc.colorAttachments[0].clearColor  = MTLClearColorMake(0.97, 0.97, 0.97, 1)

        guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else { return nil }

        var u       = sim.renderUniforms()   // includes canvas bounds + base color
        u.debugMode = 0                       // always normal render

        enc.setRenderPipelineState(renderPipeline)
        enc.setFragmentTexture(sim.colorTex,    index: 0)
        enc.setFragmentTexture(sim.velocityTex, index: 1)
        enc.setFragmentTexture(sim.pressureTex, index: 2)
        enc.setFragmentTexture(sim.densityTex,  index: 3)
        enc.setFragmentBytes(&u, length: MemoryLayout<SimUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        enc.endEncoding()

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()   // one-time capture — blocking is acceptable

        let bytesPerRow = 4 * width
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        tex.getBytes(&bytes,
                     bytesPerRow: bytesPerRow,
                     from: MTLRegionMake2D(0, 0, width, height),
                     mipmapLevel: 0)

        // Metal writes BGRA; tell CoreGraphics the layout with byteOrder32Little.
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage  = CGImage(width: width, height: height,
                                     bitsPerComponent: 8, bitsPerPixel: 32,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: bitmapInfo,
                                     provider: provider,
                                     decode: nil, shouldInterpolate: true,
                                     intent: .defaultIntent)
        else { return nil }

        return UIImage(cgImage: cgImage)
    }

    func draw(in view: MTKView) {
        guard let drawable  = view.currentDrawable,
              let passDesc  = view.currentRenderPassDescriptor,
              let cmdBuf    = sim.commandQueue.makeCommandBuffer()
        else { return }

        // Sim step
        // Pull the latest gravity from the motion service every frame so
        // tilt changes are immediate — no touch input required.
        let liveGravity = motionService?.gravity ?? gravity

        sim.step(gravity: liveGravity,
                 pourTouches: pourTouches,
                 activeTool: activeTool,
                 toolRadius: toolRadius,
                 toolForce: toolForce,
                 injectColor: injectColor,
                 debugMode: 0,
                 commandBuffer: cmdBuf)

        // Render pass — pull canvas bounds + base color from the sim so the
        // fragment shader sees the user's actual choices.
        var u           = sim.renderUniforms()
        u.gravity       = gravity
        u.pourActive    = pourTouches.isEmpty ? 0 : 1
        u.debugMode     = 0

        guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        enc.setRenderPipelineState(renderPipeline)
        enc.setFragmentTexture(sim.colorTex,    index: 0)
        enc.setFragmentTexture(sim.velocityTex, index: 1)
        enc.setFragmentTexture(sim.pressureTex, index: 2)
        enc.setFragmentTexture(sim.densityTex,  index: 3)
        enc.setFragmentBytes(&u, length: MemoryLayout<SimUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        enc.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()

        // FPS reporting (once per second)
        frameCount += 1
        let now = CACurrentMediaTime()
        if now - lastFPSTime >= 1.0 {
            let fps = Double(frameCount) / (now - lastFPSTime)
            onFPS?(fps)
            frameCount = 0
            lastFPSTime = now
        }
    }
}
