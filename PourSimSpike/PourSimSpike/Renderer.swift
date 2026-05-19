import Metal
import MetalKit

@MainActor
final class Renderer: NSObject, MTKViewDelegate {

    private let sim: FluidSimulator
    private let renderPipeline: MTLRenderPipelineState
    private var uniformsCopy: SimUniforms = SimUniforms()

    var gravity: SIMD2<Float> = .zero
    var pourPos: SIMD2<Float>? = nil
    var debugMode: UInt32 = 0

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

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable  = view.currentDrawable,
              let passDesc  = view.currentRenderPassDescriptor,
              let cmdBuf    = sim.commandQueue.makeCommandBuffer()
        else { return }

        // Sim step
        sim.step(gravity: gravity, pourPos: pourPos, debugMode: debugMode, commandBuffer: cmdBuf)

        // Render pass
        uniformsCopy.gravity    = gravity
        uniformsCopy.pourActive = pourPos != nil ? 1 : 0
        uniformsCopy.debugMode  = debugMode
        uniformsCopy.gridWidth  = UInt32(sim.gridWidth)
        uniformsCopy.gridHeight = UInt32(sim.gridHeight)

        guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        enc.setRenderPipelineState(renderPipeline)
        enc.setFragmentTexture(sim.colorTex,    index: 0)
        enc.setFragmentTexture(sim.velocityTex, index: 1)
        enc.setFragmentTexture(sim.pressureTex, index: 2)
        enc.setFragmentTexture(sim.densityTex,  index: 3)
        enc.setFragmentBytes(&uniformsCopy, length: MemoryLayout<SimUniforms>.stride, index: 0)
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
