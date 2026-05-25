import Metal
import CoreMotion

// Matches SimUniforms in Shaders.metal — layout must stay in sync.
// All fields are 4-byte aligned so the natural Swift packing matches Metal.
struct SimUniforms {
    var gravity: SIMD2<Float>   = .zero
    var dt: Float               = 1.0 / 60.0
    var viscosity: Float        = 0.0008
    var gridWidth: UInt32       = 256
    var gridHeight: UInt32      = 576
    var pourPosX: Float         = 0
    var pourPosY: Float         = 0
    var pourActive: UInt32      = 0
    var pourRadius: Float       = 14
    var debugMode: UInt32       = 0
    var injectR: Float          = 0.8
    var injectG: Float          = 0.2
    var injectB: Float          = 0.1
    var damping: Float          = 0.97
    var surfaceTension: Float   = 0.18      // bumped — keeps color blobs cohesive (taffy-like)
    var buoyancy: Float         = 6.0       // density → gravity strength

    // Canvas bounds (in cell coords). Defaults = whole grid (no border).
    var canvasMinX: Float       = 0
    var canvasMinY: Float       = 0
    var canvasMaxX: Float       = 256
    var canvasMaxY: Float       = 576
    var canvasIsRound: UInt32   = 0

    // Base color for cells that get reset (paint flowing off canvas).
    var baseR: Float            = 1.0
    var baseG: Float            = 1.0
    var baseB: Float            = 1.0

    // Per-touch drag vector (UV space) for tools that push paint (swipe/stir).
    var dragX: Float            = 0
    var dragY: Float            = 0

    // Strength multiplier from the active ToolVariant (e.g. a wire-thin
    // string pushes harder than a soft yarn at the same radius).
    var toolForce: Float        = 1.0

    // Advect boundary mode: 0 = freeze off-canvas (used for velocity so
    // pressure-solve stays stable), 1 = extrude nearest on-canvas (used for
    // color/density so linear sampling doesn't bleed base color in).
    var advectMode: UInt32      = 0
}

@MainActor
final class FluidSimulator {

    // MARK: - Grid config
    let gridWidth: Int
    let gridHeight: Int

    // MARK: - Metal state
    let device: MTLDevice
    let commandQueue: MTLCommandQueue

    // Textures — ping-pong pairs for fields that need read+write in same pass
    private(set) var colorA, colorB: MTLTexture
    private(set) var velocityA, velocityB: MTLTexture
    private(set) var densityA, densityB: MTLTexture
    private(set) var pressureA, pressureB: MTLTexture
    private(set) var divergenceTex: MTLTexture

    // Current "front" textures (what the renderer reads)
    var colorTex: MTLTexture { colorPing ? colorA : colorB }
    var velocityTex: MTLTexture { velPing ? velocityA : velocityB }
    var densityTex: MTLTexture { denPing ? densityA : densityB }
    var pressureTex: MTLTexture { prePing ? pressureA : pressureB }

    private var colorPing = true
    private var velPing   = true
    private var denPing   = true
    private var prePing   = true

    // Pipelines
    private let psFillCanvas:       MTLComputePipelineState
    private let psAddForces:        MTLComputePipelineState
    private let psSurfaceTension:   MTLComputePipelineState
    private let psAddSources:       MTLComputePipelineState
    private let psSwipeTool:        MTLComputePipelineState
    private let psStirTool:         MTLComputePipelineState
    private let psBlowTool:         MTLComputePipelineState
    private let psAdvect:           MTLComputePipelineState
    private let psDiffuse:          MTLComputePipelineState
    private let psDivergence:       MTLComputePipelineState
    private let psPressure:         MTLComputePipelineState
    private let psSubtractGradient: MTLComputePipelineState

    private var uniforms = SimUniforms()

    // Snapshot of the sim's current uniforms, for the renderer's fragment
    // pass. Canvas bounds and base color live in here and would otherwise be
    // lost if the renderer built its own SimUniforms() from scratch.
    func renderUniforms() -> SimUniforms { uniforms }

    // MARK: - Init

    init(device: MTLDevice, width: Int = 256, height: Int = 576) throws {
        self.device = device
        self.gridWidth = width
        self.gridHeight = height
        guard let q = device.makeCommandQueue() else {
            throw SimError.metalInitFailed("command queue")
        }
        commandQueue = q

        let lib = device.makeDefaultLibrary()!

        func pipeline(_ name: String) throws -> MTLComputePipelineState {
            guard let fn = lib.makeFunction(name: name) else {
                throw SimError.metalInitFailed("function \(name)")
            }
            return try device.makeComputePipelineState(function: fn)
        }

        psFillCanvas       = try pipeline("fillCanvas")
        psAddForces        = try pipeline("addForces")
        psSurfaceTension   = try pipeline("surfaceTensionForce")
        psAddSources       = try pipeline("addSources")
        psSwipeTool        = try pipeline("swipeTool")
        psStirTool         = try pipeline("stirTool")
        psBlowTool         = try pipeline("blowTool")
        psAdvect           = try pipeline("advect")
        psDiffuse          = try pipeline("diffuse")
        psDivergence       = try pipeline("divergence")
        psPressure         = try pipeline("pressure")
        psSubtractGradient = try pipeline("subtractGradient")

        func makeTex(_ pixel: MTLPixelFormat) -> MTLTexture {
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixel, width: width, height: height, mipmapped: false)
            desc.usage = [.shaderRead, .shaderWrite]
            desc.storageMode = .private
            return device.makeTexture(descriptor: desc)!
        }

        colorA    = makeTex(.rgba16Float)
        colorB    = makeTex(.rgba16Float)
        velocityA = makeTex(.rg16Float)
        velocityB = makeTex(.rg16Float)
        densityA  = makeTex(.r16Float)
        densityB  = makeTex(.r16Float)
        pressureA = makeTex(.r16Float)
        pressureB = makeTex(.r16Float)
        divergenceTex = makeTex(.r16Float)

        uniforms.gridWidth  = UInt32(width)
        uniforms.gridHeight = UInt32(height)
    }

    // Adjust viscosity and damping from a consistency value (-1=thin … +1=thick).
    // -1 (thin)   → damping 0.99, viscosity 0.0001, surface tension 0.06 — flows like water
    //  0 (medium) → damping 0.95, viscosity 0.002,  surface tension 0.18 — taffy
    // +1 (thick)  → damping 0.82, viscosity 0.020,  surface tension 0.40 — barely moves
    func applyConsistency(_ value: Float) {
        let v          = Swift.max(-1, Swift.min(1, value))
        let thinFactor = Float((1 - Double(v)) * 0.5)            // 0 thick, 1 thin
        let thickFactor = 1 - thinFactor
        uniforms.damping        = 0.82 + thinFactor * 0.17       // 0.82…0.99
        uniforms.viscosity      = 0.0001 * Float(exp(Double(thickFactor) * 5.3))
        uniforms.surfaceTension = 0.06 + thickFactor * 0.34      // 0.06…0.40
    }

    // Reshape the canvas. The full grid is always 256×576; canvas is a
    // centered sub-region (rect or circle) inside it. Cells outside become
    // "table" — paint can't be poured there and any paint that flows there
    // gets cleared back to the base color.
    func applyCanvasShape(_ shape: CanvasShape) {
        let w = Float(gridWidth)
        let h = Float(gridHeight)
        let cx = w * 0.5, cy = h * 0.5

        switch shape {
        case .portrait:
            // tall rectangle, 84% wide × 80% tall
            let halfW = w * 0.42, halfH = h * 0.40
            uniforms.canvasMinX = cx - halfW; uniforms.canvasMaxX = cx + halfW
            uniforms.canvasMinY = cy - halfH; uniforms.canvasMaxY = cy + halfH
            uniforms.canvasIsRound = 0
        case .landscape:
            // wide rectangle: same width, but shorter
            let halfW = w * 0.46, halfH = h * 0.20
            uniforms.canvasMinX = cx - halfW; uniforms.canvasMaxX = cx + halfW
            uniforms.canvasMinY = cy - halfH; uniforms.canvasMaxY = cy + halfH
            uniforms.canvasIsRound = 0
        case .square:
            let side = Swift.min(w, h) * 0.46
            uniforms.canvasMinX = cx - side; uniforms.canvasMaxX = cx + side
            uniforms.canvasMinY = cy - side; uniforms.canvasMaxY = cy + side
            uniforms.canvasIsRound = 0
        case .round:
            let r = Swift.min(w, h) * 0.46
            uniforms.canvasMinX = cx - r; uniforms.canvasMaxX = cx + r
            uniforms.canvasMinY = cy - r; uniforms.canvasMaxY = cy + r
            uniforms.canvasIsRound = 1
        }
    }

    // Remember the base color so cells that flow off-canvas can be cleared
    // back to the user's chosen base.
    func setBaseColor(rgb: SIMD3<Float>) {
        uniforms.baseR = rgb.x
        uniforms.baseG = rgb.y
        uniforms.baseB = rgb.z
    }

    // Fill every grid cell with a solid base color.  Call once before the first frame.
    func fillBase(rgb: SIMD3<Float>) {
        setBaseColor(rgb: rgb)
        var u = uniforms
        u.injectR = rgb.x; u.injectG = rgb.y; u.injectB = rgb.z

        guard let cmdBuf = commandQueue.makeCommandBuffer() else { return }

        let tg = MTLSize(width: 16, height: 16, depth: 1)
        let gc = MTLSize(width: (gridWidth  + 15) / 16,
                         height: (gridHeight + 15) / 16,
                         depth: 1)

        func fill(col: MTLTexture, den: MTLTexture) {
            guard let enc = cmdBuf.makeComputeCommandEncoder() else { return }
            enc.setComputePipelineState(psFillCanvas)
            enc.setBytes(&u, length: MemoryLayout<SimUniforms>.stride, index: 0)
            enc.setTexture(col, index: 0)
            enc.setTexture(den, index: 1)
            enc.dispatchThreadgroups(gc, threadsPerThreadgroup: tg)
            enc.endEncoding()
        }

        fill(col: colorA, den: densityA)
        fill(col: colorB, den: densityB)

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }

    // MARK: - Per-frame step

    // pourPositions: normalized [0,1] grid coords for each active finger.
    // activeTool: determines which kernel is dispatched per touch position.
    // injectColor: sRGB for this frame's active palette swatch (used by pour/drop).
    func step(gravity: SIMD2<Float>,
              pourTouches: [PourTouch],
              activeTool: Tool,
              toolRadius: Float,
              toolForce: Float,
              injectColor: SIMD3<Float>,
              debugMode: UInt32,
              commandBuffer: MTLCommandBuffer)
    {
        uniforms.gravity   = gravity
        uniforms.debugMode = debugMode
        uniforms.injectR   = injectColor.x
        uniforms.injectG   = injectColor.y
        uniforms.injectB   = injectColor.z

        let tg = MTLSize(width: 16, height: 16, depth: 1)
        let gc = MTLSize(width: (gridWidth  + 15) / 16,
                         height: (gridHeight + 15) / 16,
                         depth: 1)

        func encode(_ ps: MTLComputePipelineState, _ block: (MTLComputeCommandEncoder) -> Void) {
            guard let enc = commandBuffer.makeComputeCommandEncoder() else { return }
            enc.setComputePipelineState(ps)
            enc.setBytes(&uniforms, length: MemoryLayout<SimUniforms>.stride, index: 0)
            block(enc)
            enc.dispatchThreadgroups(gc, threadsPerThreadgroup: tg)
            enc.endEncoding()
        }

        let curVel = velPing ? velocityA : velocityB
        let curDen = denPing ? densityA : densityB
        let curCol = colorPing ? colorA : colorB

        // 1. Add forces (gravity + damping)
        encode(psAddForces) { enc in
            enc.setTexture(curVel, index: 0)
            enc.setTexture(curDen, index: 1)
        }

        // 2. Surface tension — cohesive force at density interfaces
        encode(psSurfaceTension) { enc in
            enc.setTexture(curVel, index: 0)
            enc.setTexture(curDen, index: 1)
        }

        // 3. Apply active tool — one dispatch per active finger.
        // Pour uses a per-touch growing radius; other tools use their fixed radius.
        // Map tool → pipeline. New tools (string/balloon/air/cup) re-use
        // existing kernels with different radius/force from their variant.
        let toolPipeline: MTLComputePipelineState = {
            switch activeTool {
            case .pour, .balloon, .cup: return psAddSources
            case .swipe, .string:       return psSwipeTool
            case .stir:                 return psStirTool
            case .air:                  return psBlowTool
            }
        }()

        uniforms.toolForce = toolForce

        if pourTouches.isEmpty {
            uniforms.pourActive = 0
            uniforms.pourRadius = toolRadius
            uniforms.dragX = 0; uniforms.dragY = 0
            encode(toolPipeline) { enc in
                enc.setTexture(curCol, index: 0)
                enc.setTexture(curDen, index: 1)
                enc.setTexture(curVel, index: 2)
            }
        } else {
            for touch in pourTouches {
                uniforms.pourPosX   = touch.pos.x
                uniforms.pourPosY   = touch.pos.y
                uniforms.pourActive = 1
                // Pour uses the per-touch pressure radius from TouchMTKView;
                // every other tool uses the variant's radius.
                uniforms.pourRadius = activeTool == .pour ? touch.radius : toolRadius
                uniforms.dragX      = touch.drag.x
                uniforms.dragY      = touch.drag.y
                encode(toolPipeline) { enc in
                    enc.setTexture(curCol, index: 0)
                    enc.setTexture(curDen, index: 1)
                    enc.setTexture(curVel, index: 2)
                }
            }
        }

        // 3. Advect velocity — freeze off-canvas at zero (advectMode 0)
        let nextVel = velPing ? velocityB : velocityA
        uniforms.advectMode = 0
        encode(psAdvect) { enc in
            enc.setTexture(curVel,  index: 0)
            enc.setTexture(curVel,  index: 1)
            enc.setTexture(nextVel, index: 2)
        }
        velPing.toggle()

        // 4. Diffuse velocity (~20 Jacobi iterations)
        for _ in 0..<20 {
            let src = velPing ? velocityA : velocityB
            let dst = velPing ? velocityB : velocityA
            encode(psDiffuse) { enc in
                enc.setTexture(src, index: 0)
                enc.setTexture(dst, index: 1)
            }
            velPing.toggle()
        }

        // 5a. Divergence
        let fVel = velPing ? velocityA : velocityB
        encode(psDivergence) { enc in
            enc.setTexture(fVel, index: 0)
            enc.setTexture(divergenceTex, index: 1)
        }

        // 5b. Pressure solve (~35 Jacobi iterations)
        for _ in 0..<35 {
            let src = prePing ? pressureA : pressureB
            let dst = prePing ? pressureB : pressureA
            encode(psPressure) { enc in
                enc.setTexture(src, index: 0)
                enc.setTexture(divergenceTex, index: 1)
                enc.setTexture(dst, index: 2)
            }
            prePing.toggle()
        }

        // 5c. Subtract gradient
        let fPre = prePing ? pressureA : pressureB
        encode(psSubtractGradient) { enc in
            enc.setTexture(velPing ? velocityA : velocityB, index: 0)
            enc.setTexture(fPre, index: 1)
        }

        // 6. Advect color — extrude nearest on-canvas value off-canvas
        //    (advectMode 1) so the linear sampler doesn't bleed base color
        //    in at the boundary.
        let nextCol = colorPing ? colorB : colorA
        let advVel  = velPing ? velocityA : velocityB
        uniforms.advectMode = 1
        encode(psAdvect) { enc in
            enc.setTexture(advVel,  index: 0)
            enc.setTexture(curCol,  index: 1)
            enc.setTexture(nextCol, index: 2)
        }
        colorPing.toggle()

        // 6b. Advect density — same extrude mode
        let nextDen = denPing ? densityB : densityA
        let curDen2 = denPing ? densityA : densityB
        encode(psAdvect) { enc in
            enc.setTexture(advVel,  index: 0)
            enc.setTexture(curDen2, index: 1)
            enc.setTexture(nextDen, index: 2)
        }
        denPing.toggle()
    }
}

enum SimError: Error {
    case metalInitFailed(String)
}
