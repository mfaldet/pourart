import Metal
import CoreMotion

// Matches SimUniforms in Shaders.metal — layout must stay in sync.
// All fields are 4-byte aligned so the natural Swift packing matches Metal.
struct SimUniforms {
    var gravity: SIMD2<Float>   = .zero
    var dt: Float               = 1.0 / 60.0
    var viscosity: Float        = 0.0008    // up from 0.0001 — paint is honey, not water
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
    var damping: Float          = 0.94      // per-frame velocity multiplier
    var surfaceTension: Float   = 0.0       // plumbed; kernel lands in a follow-up
    var buoyancy: Float         = 4.0       // density → gravity strength
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
    private let psAddForces:       MTLComputePipelineState
    private let psAddSources:      MTLComputePipelineState
    private let psAdvect:          MTLComputePipelineState
    private let psDiffuse:         MTLComputePipelineState
    private let psDivergence:      MTLComputePipelineState
    private let psPressure:        MTLComputePipelineState
    private let psSubtractGradient:MTLComputePipelineState

    private var uniforms = SimUniforms()

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

        psAddForces        = try pipeline("addForces")
        psAddSources       = try pipeline("addSources")
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

    // MARK: - Per-frame step

    func step(gravity: SIMD2<Float>,
              pourPos: SIMD2<Float>?,
              injectColor: SIMD3<Float>,
              debugMode: UInt32,
              commandBuffer: MTLCommandBuffer)
    {
        uniforms.gravity   = gravity
        uniforms.debugMode = debugMode
        uniforms.injectR   = injectColor.x
        uniforms.injectG   = injectColor.y
        uniforms.injectB   = injectColor.z
        if let p = pourPos {
            uniforms.pourPosX  = p.x
            uniforms.pourPosY  = p.y
            uniforms.pourActive = 1
        } else {
            uniforms.pourActive = 0
        }

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

        // 1. Add forces
        encode(psAddForces) { enc in
            enc.setTexture(curVel, index: 0)
            enc.setTexture(curDen, index: 1)
        }

        // 2. Add sources
        encode(psAddSources) { enc in
            enc.setTexture(curCol, index: 0)
            enc.setTexture(curDen, index: 1)
            enc.setTexture(curVel, index: 2)
        }

        // 3. Advect velocity
        let nextVel = velPing ? velocityB : velocityA
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

        // 6. Advect color
        let nextCol = colorPing ? colorB : colorA
        let advVel  = velPing ? velocityA : velocityB
        encode(psAdvect) { enc in
            enc.setTexture(advVel,  index: 0)
            enc.setTexture(curCol,  index: 1)
            enc.setTexture(nextCol, index: 2)
        }
        colorPing.toggle()

        // 6b. Advect density
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
