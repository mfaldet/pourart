#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Uniforms pushed from CPU each frame.
// Layout must match SimUniforms in FluidSimulator.swift exactly.
// ---------------------------------------------------------------------------
struct SimUniforms {
    float2 gravity;       // device-motion gravity, scaled by strength
    float  dt;            // timestep (seconds)
    float  viscosity;     // global viscosity coefficient
    uint2  gridSize;      // (width, height) in cells
    float2 pourPos;       // normalized [0,1] pour position
    uint   pourActive;    // 1 if user is pouring
    float  pourRadius;    // radius in cells
    uint   debugMode;     // 0=off 1=velocity 2=pressure 3=density
    float  injectR;       // pour color, sRGB
    float  injectG;
    float  injectB;
    float  damping;       // per-frame velocity multiplier (e.g. 0.92)
    float  surfaceTension; // unused in M1 commit, plumbed for follow-up
    float  buoyancy;      // density → gravity multiplier
};

// ---------------------------------------------------------------------------
// Oklab color space helpers
//
// Pour paint colors are stored in the grid as Oklab (L, a, b in .xyz, opacity
// in .w). Oklab is perceptually uniform — linearly interpolating two Oklab
// colors gives a mix that looks like real pigment mixing, not the muddy
// brown you get from RGB averaging.
//
// Math: Björn Ottosson, https://bottosson.github.io/posts/oklab/
// ---------------------------------------------------------------------------
static float3 rgbToOklab(float3 c) {
    float l = 0.4122214708f * c.r + 0.5363325363f * c.g + 0.0514459929f * c.b;
    float m = 0.2119034982f * c.r + 0.6806995451f * c.g + 0.1073969566f * c.b;
    float s = 0.0883024619f * c.r + 0.2817188376f * c.g + 0.6299787005f * c.b;

    float l_ = pow(l, 1.0f / 3.0f);
    float m_ = pow(m, 1.0f / 3.0f);
    float s_ = pow(s, 1.0f / 3.0f);

    return float3(
        0.2104542553f * l_ + 0.7936177850f * m_ - 0.0040720468f * s_,
        1.9779984951f * l_ - 2.4285922050f * m_ + 0.4505937099f * s_,
        0.0259040371f * l_ + 0.7827717662f * m_ - 0.8086757660f * s_
    );
}

static float3 oklabToRgb(float3 lab) {
    float l_ = lab.x + 0.3963377774f * lab.y + 0.2158037573f * lab.z;
    float m_ = lab.x - 0.1055613458f * lab.y - 0.0638541728f * lab.z;
    float s_ = lab.x - 0.0894841775f * lab.y - 1.2914855480f * lab.z;

    float l = l_ * l_ * l_;
    float m = m_ * m_ * m_;
    float s = s_ * s_ * s_;

    return float3(
         4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s,
        -1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s,
        -0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s
    );
}

// ---------------------------------------------------------------------------
// 1. Add forces — gravity + buoyancy + per-frame velocity damping
//
// Damping is what makes the fluid feel like honey instead of water. Real
// pour paint dissipates velocity quickly; an unconstrained Stable Fluids
// sim is essentially inviscid and keeps moving forever.
// ---------------------------------------------------------------------------
kernel void addForces(texture2d<float, access::read_write> velocity [[texture(0)]],
                      texture2d<float, access::read>       density  [[texture(1)]],
                      constant SimUniforms& u                       [[buffer(0)]],
                      uint2 gid                                     [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float4 vel = velocity.read(gid);
    float  den = density.read(gid).r;

    // Per-frame damping — simulates internal friction of viscous paint.
    vel.xy *= u.damping;

    // Gravity scaled by local density (heavier paint flows faster).
    // The buoyancy term lets the user dial how much density affects flow —
    // critical for cell formation where the Drop tool injects off-density
    // paint that needs to actually rise or sink through neighbours.
    vel.xy += u.gravity * den * u.buoyancy * u.dt;

    // Velocity clamping — guards against tilt-reversal blow-up.
    float speed = length(vel.xy);
    if (speed > 50.0) vel.xy = normalize(vel.xy) * 50.0;

    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// 2. Add sources — inject palette color (converted to Oklab) at pour point
// ---------------------------------------------------------------------------
kernel void addSources(texture2d<float, access::read_write> color   [[texture(0)]],
                       texture2d<float, access::read_write> density [[texture(1)]],
                       texture2d<float, access::read_write> velocity[[texture(2)]],
                       constant SimUniforms& u                      [[buffer(0)]],
                       uint2 gid                                    [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float2 cellPos  = float2(gid);
    float2 pourCell = u.pourPos * float2(u.gridSize);
    float  dist     = length(cellPos - pourCell);
    if (dist >= u.pourRadius) return;

    float strength = (1.0 - dist / u.pourRadius) * u.dt * 8.0;
    strength = clamp(strength, 0.0, 1.0);

    // Convert palette RGB → Oklab for perceptual mixing in the grid.
    float3 injectLab = rgbToOklab(float3(u.injectR, u.injectG, u.injectB));

    // Read current cell (Oklab in .xyz, opacity in .w).
    float4 cur = color.read(gid);
    float  curOpacity = cur.w;

    // Mix as a proper opacity-weighted running average. This avoids the
    // "ghost black" bug where an empty cell's (0,0,0) Oklab would be lerped
    // toward the injection color through dark intermediate shades.
    //   blendWeight = 1 when curOpacity = 0 (full replacement)
    //   blendWeight ≈ strength/curOpacity when cell is already painted
    float  blendWeight = strength / max(curOpacity + strength, 1e-4);
    float3 newLab = mix(cur.xyz, injectLab, blendWeight);
    float  newOpacity = clamp(curOpacity + strength, 0.0, 1.0);

    color.write(float4(newLab, newOpacity), gid);

    // Density injection — slight overshoot so fresh paint is buoyant.
    // This is what makes pours pile up briefly before flowing.
    float curDen = density.read(gid).r;
    density.write(float4(clamp(curDen + strength * 1.2, 0.0, 1.2)), gid);
}

// ---------------------------------------------------------------------------
// 3. Advect — semi-Lagrangian backtrace for any float4 field
// ---------------------------------------------------------------------------
kernel void advect(texture2d<float, access::read>        velocity [[texture(0)]],
                   texture2d<float, access::sample>      fieldIn  [[texture(1)]],
                   texture2d<float, access::write>       fieldOut [[texture(2)]],
                   constant SimUniforms& u                        [[buffer(0)]],
                   uint2 gid                                      [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float2 gridSizeF = float2(u.gridSize);
    float2 uv = (float2(gid) + 0.5) / gridSizeF;
    float2 vel = velocity.read(gid).xy;

    // Backtrace position in UV space.
    float2 prevUV = uv - vel * u.dt / gridSizeF;
    prevUV = clamp(prevUV, 0.5 / gridSizeF, 1.0 - 0.5 / gridSizeF);

    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 val = fieldIn.sample(s, prevUV);
    fieldOut.write(val, gid);
}

// ---------------------------------------------------------------------------
// 4. Diffuse — Jacobi iteration for viscosity diffusion (one of ~20/frame)
// ---------------------------------------------------------------------------
kernel void diffuse(texture2d<float, access::read>  velIn  [[texture(0)]],
                    texture2d<float, access::write> velOut [[texture(1)]],
                    constant SimUniforms& u                [[buffer(0)]],
                    uint2 gid                              [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float alpha = 1.0 / max(u.viscosity * u.dt, 1e-6);
    float beta  = 4.0 + alpha;

    uint2 l  = uint2(max((int)gid.x - 1, 0),               gid.y);
    uint2 r  = uint2(min(gid.x + 1, u.gridSize.x - 1),     gid.y);
    uint2 d  = uint2(gid.x, max((int)gid.y - 1, 0));
    uint2 up = uint2(gid.x, min(gid.y + 1, u.gridSize.y - 1));

    float4 val = (velIn.read(l) + velIn.read(r) + velIn.read(d) + velIn.read(up)
                  + alpha * velIn.read(gid)) / beta;
    velOut.write(val, gid);
}

// ---------------------------------------------------------------------------
// 5a. Divergence
// ---------------------------------------------------------------------------
kernel void divergence(texture2d<float, access::read>  velocity [[texture(0)]],
                       texture2d<float, access::write> divOut   [[texture(1)]],
                       constant SimUniforms& u                  [[buffer(0)]],
                       uint2 gid                                [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    uint2 l  = uint2(max((int)gid.x - 1, 0),               gid.y);
    uint2 r  = uint2(min(gid.x + 1, u.gridSize.x - 1),     gid.y);
    uint2 dn = uint2(gid.x, max((int)gid.y - 1, 0));
    uint2 up = uint2(gid.x, min(gid.y + 1, u.gridSize.y - 1));

    float div = 0.5 * ((velocity.read(r).x - velocity.read(l).x) +
                        (velocity.read(up).y - velocity.read(dn).y));
    divOut.write(float4(div, 0, 0, 1), gid);
}

// ---------------------------------------------------------------------------
// 5b. Pressure — Jacobi iteration (one of ~35/frame)
// ---------------------------------------------------------------------------
kernel void pressure(texture2d<float, access::read>  pressIn  [[texture(0)]],
                     texture2d<float, access::read>  divIn    [[texture(1)]],
                     texture2d<float, access::write> pressOut [[texture(2)]],
                     constant SimUniforms& u                  [[buffer(0)]],
                     uint2 gid                                [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    uint2 l  = uint2(max((int)gid.x - 1, 0),               gid.y);
    uint2 r  = uint2(min(gid.x + 1, u.gridSize.x - 1),     gid.y);
    uint2 dn = uint2(gid.x, max((int)gid.y - 1, 0));
    uint2 up = uint2(gid.x, min(gid.y + 1, u.gridSize.y - 1));

    float div = divIn.read(gid).r;
    float p = (pressIn.read(l).r + pressIn.read(r).r +
               pressIn.read(dn).r + pressIn.read(up).r - div) * 0.25;
    pressOut.write(float4(p, 0, 0, 1), gid);
}

// ---------------------------------------------------------------------------
// 5c. Subtract gradient — enforce incompressibility
// ---------------------------------------------------------------------------
kernel void subtractGradient(texture2d<float, access::read_write> velocity [[texture(0)]],
                              texture2d<float, access::read>       pressIn  [[texture(1)]],
                              constant SimUniforms& u                       [[buffer(0)]],
                              uint2 gid                                     [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    uint2 l  = uint2(max((int)gid.x - 1, 0),               gid.y);
    uint2 r  = uint2(min(gid.x + 1, u.gridSize.x - 1),     gid.y);
    uint2 dn = uint2(gid.x, max((int)gid.y - 1, 0));
    uint2 up = uint2(gid.x, min(gid.y + 1, u.gridSize.y - 1));

    float4 vel = velocity.read(gid);
    vel.x -= 0.5 * (pressIn.read(r).r - pressIn.read(l).r);
    vel.y -= 0.5 * (pressIn.read(up).r - pressIn.read(dn).r);

    // Sticky-wall boundary — paint cannot leave canvas.
    if (gid.x == 0 || gid.x == u.gridSize.x - 1) vel.x = 0;
    if (gid.y == 0 || gid.y == u.gridSize.y - 1) vel.y = 0;

    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// 6. Render — Oklab color field to screen with debug overlays
// ---------------------------------------------------------------------------
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut fullscreenVert(uint vid [[vertex_id]]) {
    const float2 positions[6] = {
        {-1,-1},{1,-1},{-1,1},
        {-1, 1},{1,-1},{ 1,1}
    };
    const float2 uvs[6] = {
        {0,1},{1,1},{0,0},
        {0,0},{1,1},{1,0}
    };
    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.uv = uvs[vid];
    return out;
}

fragment float4 renderFrag(VertexOut in               [[stage_in]],
                            texture2d<float> colorTex  [[texture(0)]],
                            texture2d<float> velocityTex[[texture(1)]],
                            texture2d<float> pressureTex[[texture(2)]],
                            texture2d<float> densityTex [[texture(3)]],
                            constant SimUniforms& u     [[buffer(0)]])
{
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    if (u.debugMode == 1) {
        float2 vel = velocityTex.sample(s, in.uv).xy;
        float speed = length(vel) / 20.0;
        return float4(speed, abs(vel.x) / 10.0, abs(vel.y) / 10.0, 1.0);
    } else if (u.debugMode == 2) {
        float p = pressureTex.sample(s, in.uv).r;
        return float4(max(p, 0.0), 0.0, max(-p, 0.0), 1.0) * 5.0 + float4(0.05);
    } else if (u.debugMode == 3) {
        float d = densityTex.sample(s, in.uv).r;
        return float4(d, d, d, 1.0);
    }

    // Normal render: convert Oklab grid color back to RGB and composite over
    // the canvas with a faint gloss based on density.
    float4 paint = colorTex.sample(s, in.uv);
    float3 paintRgb = oklabToRgb(paint.xyz);
    paintRgb = clamp(paintRgb, 0.0, 1.0);

    float3 canvas = float3(0.97);
    float3 col = mix(canvas, paintRgb, paint.w);

    // Subtle gloss highlight on dense paint — feels wet.
    float density = densityTex.sample(s, in.uv).r;
    col += float3(0.04) * density * density;

    return float4(clamp(col, 0.0, 1.0), 1.0);
}
