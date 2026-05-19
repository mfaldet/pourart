#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Uniforms pushed from CPU each frame
// ---------------------------------------------------------------------------
struct SimUniforms {
    float2 gravity;       // normalized device-motion gravity, scaled by strength
    float  dt;            // timestep (seconds)
    float  viscosity;     // global viscosity coefficient
    uint2  gridSize;      // (width, height) in cells
    float2 pourPos;       // normalized [0,1] pour position (invalid if pourActive==0)
    uint   pourActive;    // 1 if user is pouring
    float  pourRadius;    // radius in cells
    uint   debugMode;     // 0=off 1=velocity 2=pressure 3=density
};

// ---------------------------------------------------------------------------
// Helper: bilinear sample from a float2 texture (velocity)
// ---------------------------------------------------------------------------
static float2 bilinearVelocity(texture2d<float, access::sample> tex,
                                float2 uv,
                                sampler s) {
    return tex.sample(s, uv).xy;
}

// ---------------------------------------------------------------------------
// 1. Add forces — apply gravity to velocity field
// ---------------------------------------------------------------------------
kernel void addForces(texture2d<float, access::read_write> velocity [[texture(0)]],
                      texture2d<float, access::read>       density  [[texture(1)]],
                      constant SimUniforms& u                       [[buffer(0)]],
                      uint2 gid                                     [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float4 vel = velocity.read(gid);
    float  den = density.read(gid).r;

    // Gravity scaled by local density so denser paint flows faster
    vel.xy += u.gravity * den * u.dt;

    // Velocity clamping — prevents blow-up under aggressive tilt reversals
    float speed = length(vel.xy);
    if (speed > 50.0) vel.xy = normalize(vel.xy) * 50.0;

    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// 2. Add sources — inject color and density at the pour point
// ---------------------------------------------------------------------------
kernel void addSources(texture2d<float, access::read_write> color   [[texture(0)]],
                       texture2d<float, access::read_write> density [[texture(1)]],
                       texture2d<float, access::read_write> velocity[[texture(2)]],
                       constant SimUniforms& u                      [[buffer(0)]],
                       uint2 gid                                    [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float2 cellPos = float2(gid);
    float2 pourCell = u.pourPos * float2(u.gridSize);
    float  dist = length(cellPos - pourCell);

    if (dist < u.pourRadius) {
        float strength = 1.0 - (dist / u.pourRadius);
        // Inject a red-ish color for the spike (M0 is single-color)
        float4 src = float4(0.8, 0.2, 0.1, 1.0) * strength * u.dt * 20.0;
        float4 cur = color.read(gid);
        color.write(clamp(cur + src, 0.0, 1.0), gid);

        float curDen = density.read(gid).r;
        density.write(float4(clamp(curDen + strength * u.dt * 15.0, 0.0, 1.0)), gid);
    }
}

// ---------------------------------------------------------------------------
// 3. Advect — semi-Lagrangian backtrace for any float4 field
// ---------------------------------------------------------------------------
kernel void advect(texture2d<float, access::read>        velocity [[texture(0)]],
                   texture2d<float, access::read>        fieldIn  [[texture(1)]],
                   texture2d<float, access::write>       fieldOut [[texture(2)]],
                   constant SimUniforms& u                        [[buffer(0)]],
                   uint2 gid                                      [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float2 gridSizeF = float2(u.gridSize);
    float2 uv = (float2(gid) + 0.5) / gridSizeF;

    // Read velocity at this cell
    float2 vel = velocity.read(gid).xy;

    // Backtrace position in UV space
    float2 prevUV = uv - vel * u.dt / gridSizeF;
    prevUV = clamp(prevUV, 0.5 / gridSizeF, 1.0 - 0.5 / gridSizeF);

    // Bilinear sample from previous position
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 val = fieldIn.sample(s, prevUV);
    fieldOut.write(val, gid);
}

// ---------------------------------------------------------------------------
// 4. Diffuse — single Jacobi iteration for viscosity diffusion
//    Run this kernel ~20 times per frame
// ---------------------------------------------------------------------------
kernel void diffuse(texture2d<float, access::read>  velIn  [[texture(0)]],
                    texture2d<float, access::write> velOut [[texture(1)]],
                    constant SimUniforms& u                [[buffer(0)]],
                    uint2 gid                              [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float alpha = 1.0 / (u.viscosity * u.dt);
    float beta  = 4.0 + alpha;

    // Neighbour reads with boundary clamping
    uint2 l = uint2(max((int)gid.x - 1, 0),               gid.y);
    uint2 r = uint2(min(gid.x + 1, u.gridSize.x - 1),     gid.y);
    uint2 d = uint2(gid.x, max((int)gid.y - 1, 0));
    uint2 up= uint2(gid.x, min(gid.y + 1, u.gridSize.y - 1));

    float4 val = (velIn.read(l) + velIn.read(r) + velIn.read(d) + velIn.read(up) + alpha * velIn.read(gid)) / beta;
    velOut.write(val, gid);
}

// ---------------------------------------------------------------------------
// 5a. Divergence — prerequisite for pressure solve
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
// 5b. Pressure — single Jacobi iteration
//     Run ~30–40 times per frame
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

    // Sticky-wall boundary: zero normal velocity at edges
    if (gid.x == 0 || gid.x == u.gridSize.x - 1) vel.x = 0;
    if (gid.y == 0 || gid.y == u.gridSize.y - 1) vel.y = 0;

    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// 6. Render — color field to screen, with optional debug overlays
// ---------------------------------------------------------------------------
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut fullscreenVert(uint vid [[vertex_id]]) {
    // Two triangles covering NDC
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
        // Velocity: map to red-green
        float2 vel = velocityTex.sample(s, in.uv).xy;
        float speed = length(vel) / 20.0;
        return float4(speed, abs(vel.x) / 10.0, abs(vel.y) / 10.0, 1.0);
    } else if (u.debugMode == 2) {
        // Pressure: blue=negative, red=positive
        float p = pressureTex.sample(s, in.uv).r;
        return float4(max(p, 0.0), 0.0, max(-p, 0.0), 1.0) * 5.0 + float4(0.05);
    } else if (u.debugMode == 3) {
        // Density: grayscale
        float d = densityTex.sample(s, in.uv).r;
        return float4(d, d, d, 1.0);
    }

    // Normal render: paint color over white canvas with slight gloss
    float4 paint = colorTex.sample(s, in.uv);
    float3 canvas = float3(0.97);
    float3 col = mix(canvas, paint.rgb, paint.a);
    // Fake gloss: brighten based on density
    float density = densityTex.sample(s, in.uv).r;
    col = col + float3(0.05) * density * density;
    return float4(clamp(col, 0.0, 1.0), 1.0);
}
