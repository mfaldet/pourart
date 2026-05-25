#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Uniforms pushed from CPU each frame.
// Layout must match SimUniforms in FluidSimulator.swift exactly.
// ---------------------------------------------------------------------------
struct SimUniforms {
    float2 gravity;
    float  dt;
    float  viscosity;
    uint2  gridSize;
    float2 pourPos;
    uint   pourActive;
    float  pourRadius;
    uint   debugMode;
    float  injectR;
    float  injectG;
    float  injectB;
    float  damping;
    float  surfaceTension;
    float  buoyancy;
    float  canvasMinX;
    float  canvasMinY;
    float  canvasMaxX;
    float  canvasMaxY;
    uint   canvasIsRound;
    float  baseR;
    float  baseG;
    float  baseB;
    float  dragX;
    float  dragY;
    float  toolForce;    // variant strength multiplier
    uint   advectMode;   // 0=freeze (vel) · 1=extrude (color/density)
};

// Distance from a cell-space point `p` to the line segment swept between
// the previous touch sample (pourPos - drag) and the current sample
// (pourPos). All in cell coordinates. Treating a tool stamp as a capsule
// along the swept segment is what keeps fast drags continuous instead of
// dotted at the per-sample stride.
static float distToTouchSegment(float2 p, constant SimUniforms& u, float2 gridSize) {
    float2 toCell   = u.pourPos                                  * gridSize;
    float2 fromCell = (u.pourPos - float2(u.dragX, u.dragY))     * gridSize;
    float2 seg      = toCell - fromCell;
    float  segLen2  = dot(seg, seg);
    float  t        = (segLen2 > 1e-4f)
                      ? saturate(dot(p - fromCell, seg) / segLen2)
                      : 0.0f;
    float2 nearest  = fromCell + seg * t;
    return length(p - nearest);
}

// True if a cell-space position falls inside the active canvas mask.
static bool isOnCanvas(float2 p, constant SimUniforms& u) {
    if (u.canvasIsRound != 0) {
        float2 c = float2(u.canvasMinX + u.canvasMaxX,
                          u.canvasMinY + u.canvasMaxY) * 0.5;
        float r = (u.canvasMaxX - u.canvasMinX) * 0.5;
        return distance(p, c) <= r;
    }
    return p.x >= u.canvasMinX && p.x <= u.canvasMaxX
        && p.y >= u.canvasMinY && p.y <= u.canvasMaxY;
}

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

    // Cells outside the canvas can't hold momentum — they're the "table".
    if (!isOnCanvas(float2(gid), u)) {
        velocity.write(float4(0.0), gid);
        return;
    }

    float4 vel = velocity.read(gid);
    float  den = density.read(gid).r;

    // Per-frame damping — simulates internal friction of viscous paint.
    vel.xy *= u.damping;

    // Gravity scaled by local density (heavier paint flows faster).
    vel.xy += u.gravity * den * u.buoyancy * u.dt;

    // Velocity clamping — guards against tilt-reversal blow-up.
    float speed = length(vel.xy);
    if (speed > 200.0) vel.xy = normalize(vel.xy) * 200.0;

    // Static-friction settle: when the gravity uniform is zero (i.e. phone
    // is inside the 15° tilt deadzone) AND the remaining velocity is small,
    // snap to zero. This stops real acrylic paint from drifting forever via
    // residual surface-tension forces. Outside the deadzone gravity is
    // non-zero, so paint can build up flow normally even at slight tilts.
    if (length(u.gravity) < 0.1 && speed < 0.8) {
        vel.xy = float2(0);
    }

    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// 2. Surface tension — Continuum Surface Force (CSF) method
//
// Pour paint has high surface tension relative to its viscosity. This creates:
//   • Cohesion: paint regions resist breaking apart into thin films
//   • Lacing: curved, minimized boundaries between color zones
//   • Beading: dense paint pools rather than spreading uniformly
//
// Algorithm: F_st = σ · (∇²ρ) · ∇ρ
//   ∇ρ  = density gradient (zero in flat regions, large at interfaces)
//   ∇²ρ = Laplacian of density (curvature of the density field)
//
// Weighting by ∇ρ (not normalized) naturally concentrates the force at
// density interfaces and zeroes it out in flat paint regions. The sign of
// the Laplacian makes the force cohesive: at the edge of a paint blob the
// Laplacian is negative, so F points inward, pulling the blob together.
// ---------------------------------------------------------------------------
kernel void surfaceTensionForce(
    texture2d<float, access::read_write> velocity [[texture(0)]],
    texture2d<float, access::read>       density  [[texture(1)]],
    constant SimUniforms& u                       [[buffer(0)]],
    uint2 gid                                     [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;
    if (u.surfaceTension == 0.0f) return;
    if (!isOnCanvas(float2(gid), u)) return;

    uint2 l  = uint2(max((int)gid.x - 1, 0),               gid.y);
    uint2 r  = uint2(min(gid.x + 1, u.gridSize.x - 1),     gid.y);
    uint2 dn = uint2(gid.x, max((int)gid.y - 1, 0));
    uint2 up = uint2(gid.x, min(gid.y + 1, u.gridSize.y - 1));

    float rho  = density.read(gid).r;
    // Off-canvas neighbors don't actually exist as paint — using their
    // (zero) density would create a fake huge gradient at the canvas edge,
    // sucking paint inward. Mirror the center cell's density instead so
    // the boundary sees a flat density field.
    float rhoL = isOnCanvas(float2(l),  u) ? density.read(l).r  : rho;
    float rhoR = isOnCanvas(float2(r),  u) ? density.read(r).r  : rho;
    float rhoD = isOnCanvas(float2(dn), u) ? density.read(dn).r : rho;
    float rhoU = isOnCanvas(float2(up), u) ? density.read(up).r : rho;

    float2 grad     = float2(rhoR - rhoL, rhoU - rhoD) * 0.5f;
    float  gradLen  = length(grad);
    if (gradLen < 1e-5f) return;   // flat region — no interface, no force

    float laplacian = rhoL + rhoR + rhoD + rhoU - 4.0f * rho;

    // CSF force: proportional to curvature × gradient magnitude
    float2 stForce = u.surfaceTension * laplacian * grad;

    float4 vel = velocity.read(gid);
    vel.xy += stForce * u.dt;

    float speed = length(vel.xy);
    if (speed > 50.0f) vel.xy = normalize(vel.xy) * 50.0f;

    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// 3. Add sources — inject palette color (converted to Oklab) at pour point
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
    if (!isOnCanvas(cellPos, u)) return;     // can't pour on the table

    // Distance to the swept segment (capsule), not just the endpoint.
    // Fast drags now produce continuous strokes instead of separated dots.
    float dist = distToTouchSegment(cellPos, u, float2(u.gridSize));
    if (dist >= u.pourRadius) return;

    // Hard-edged stamp: inside the radius the cell becomes pure inject color.
    // Adjacent colors only mix later via advection when the canvas tilts.
    float3 injectLab = rgbToOklab(float3(u.injectR, u.injectG, u.injectB));
    color.write(float4(injectLab, 1.0), gid);
    density.write(float4(1.2, 0.0, 0.0, 0.0), gid);
}

// ---------------------------------------------------------------------------
// Tool kernels — Drop, Wipe, Thinner, Thickener
//
// All share the same texture signature as addSources (color, density, velocity)
// so FluidSimulator can dispatch them identically. Each only writes the fields
// it actually changes.
//
// pourPos / pourRadius / pourActive in the uniforms carry the tool position and
// active flag for all tools — the semantics are the same, only the effect differs.
// ---------------------------------------------------------------------------

// Drop — injects a high-density paint blob that acts like a silicone-oil droplet.
// The 3× density overshoot creates a buoyancy mismatch with surrounding paint;
// the buoyancy term in addForces then drives it to rise or sink, triggering
// Rayleigh-Taylor instability and cell formation at the boundaries.
kernel void dropTool(texture2d<float, access::read_write> color    [[texture(0)]],
                     texture2d<float, access::read_write> density  [[texture(1)]],
                     texture2d<float, access::read_write> velocity [[texture(2)]],
                     constant SimUniforms& u                       [[buffer(0)]],
                     uint2 gid                                     [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float2 cellPos  = float2(gid);
    float2 dropCell = u.pourPos * float2(u.gridSize);
    float  dist     = length(cellPos - dropCell);
    if (dist >= u.pourRadius) return;

    float t        = 1.0f - dist / u.pourRadius;
    float strength = clamp(t * t * u.dt * 14.0f, 0.0f, 1.0f);

    // Full color replacement — the drop has a definite color.
    float3 injectLab = rgbToOklab(float3(u.injectR, u.injectG, u.injectB));
    float4 cur = color.read(gid);
    float  blendW = strength / max(cur.w + strength, 1e-4f);
    color.write(float4(mix(cur.xyz, injectLab, blendW),
                       clamp(cur.w + strength, 0.0f, 1.0f)), gid);

    // 3× density overshoot — critical for cell seeding.
    float curDen = density.read(gid).r;
    density.write(float4(clamp(curDen + strength * 3.0f, 0.0f, 3.0f)), gid);

    // Radially outward impulse — perturbs the interface to seed instability.
    float2 dir = (dist > 0.5f) ? normalize(cellPos - dropCell) : float2(0.0f, 1.0f);
    float4 vel = velocity.read(gid);
    vel.xy += dir * strength * 6.0f;
    float spd = length(vel.xy);
    if (spd > 50.0f) vel.xy = normalize(vel.xy) * 50.0f;
    velocity.write(vel, gid);
}

// Wipe — gradually erodes color opacity and density in the tool radius.
// Gradual rather than instant so a slow drag creates a smooth smear effect.
kernel void wipeTool(texture2d<float, access::read_write> color    [[texture(0)]],
                     texture2d<float, access::read_write> density  [[texture(1)]],
                     texture2d<float, access::read_write> velocity [[texture(2)]],
                     constant SimUniforms& u                       [[buffer(0)]],
                     uint2 gid                                     [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float2 cellPos = float2(gid);
    // Swept-segment distance so quick wipe strokes are continuous.
    float  dist    = distToTouchSegment(cellPos, u, float2(u.gridSize));
    if (dist >= u.pourRadius) return;

    float t       = 1.0f - dist / u.pourRadius;
    float wipeStr = clamp(t * t * u.dt * 6.0f, 0.0f, 1.0f);

    float4 cur = color.read(gid);
    float newOpacity = clamp(cur.w - wipeStr, 0.0f, 1.0f);
    color.write(float4(cur.xyz, newOpacity), gid);

    float curDen = density.read(gid).r;
    density.write(float4(clamp(curDen - wipeStr, 0.0f, 1.0f)), gid);

    float4 vel = velocity.read(gid);
    vel.xy *= max(1.0f - wipeStr * 0.6f, 0.0f);
    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// Swipe — drags paint in the direction the finger is moving. Acts like a
// palette knife: doesn't inject new color, just shoves the velocity field
// along the user's drag vector. Stretches existing paint into streaks.
// ---------------------------------------------------------------------------
kernel void swipeTool(texture2d<float, access::read_write> color    [[texture(0)]],
                      texture2d<float, access::read_write> density  [[texture(1)]],
                      texture2d<float, access::read_write> velocity [[texture(2)]],
                      constant SimUniforms& u                       [[buffer(0)]],
                      uint2 gid                                     [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;
    if (!isOnCanvas(float2(gid), u)) return;

    float2 cell    = float2(gid);
    // Swept-segment distance so a swipe pushes the whole path, not dots.
    float  dist    = distToTouchSegment(cell, u, float2(u.gridSize));
    if (dist >= u.pourRadius) return;

    // Drag vector → cells per second (UV * gridSize).
    float2 drag = float2(u.dragX, u.dragY) * float2(u.gridSize);
    float  dragMag = length(drag);
    if (dragMag < 0.001f) return;

    // Drag carries both direction and speed — multiply by falloff, the
    // variant's toolForce, and a gain so a single brisk swipe noticeably
    // stretches the paint.
    float falloff = 1.0f - dist / u.pourRadius;
    float4 vel = velocity.read(gid);
    vel.xy += drag * falloff * 220.0f * u.toolForce;
    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// Stir — rotational impulse around the finger. Adds tangential velocity so
// existing paint swirls into spirals. Direction follows the drag sign.
// ---------------------------------------------------------------------------
kernel void stirTool(texture2d<float, access::read_write> color    [[texture(0)]],
                     texture2d<float, access::read_write> density  [[texture(1)]],
                     texture2d<float, access::read_write> velocity [[texture(2)]],
                     constant SimUniforms& u                       [[buffer(0)]],
                     uint2 gid                                     [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;
    if (!isOnCanvas(float2(gid), u)) return;

    float2 cell = float2(gid);
    float2 here = u.pourPos * float2(u.gridSize);
    float2 r    = cell - here;
    float  dist = length(r);
    if (dist < 0.5f || dist >= u.pourRadius) return;

    // Sign of the angular twist comes from the drag direction (cross product
    // of "outward from center" × "drag direction"). Means stroking around the
    // touch in either direction reinforces the swirl.
    float2 drag = float2(u.dragX, u.dragY) * float2(u.gridSize);
    float dragMag = length(drag);
    if (dragMag < 0.001f) return;

    // Tangent vector — rotate (r) by 90°
    float2 tangent = float2(-r.y, r.x) / max(dist, 1e-4);
    float  twist   = sign(tangent.x * drag.x + tangent.y * drag.y);
    if (twist == 0) twist = 1;

    float falloff = 1.0f - dist / u.pourRadius;
    float push    = falloff * dragMag * 80.0f * u.toolForce;

    float4 vel = velocity.read(gid);
    vel.xy += tangent * push * twist;
    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// Blow — radially outward velocity (hair dryer / air compressor / straw).
// No paint injection. Force is proportional to falloff × toolForce so the
// "Compressor" variant punches harder than "Dryer" in a smaller area.
// ---------------------------------------------------------------------------
kernel void blowTool(texture2d<float, access::read_write> color    [[texture(0)]],
                     texture2d<float, access::read_write> density  [[texture(1)]],
                     texture2d<float, access::read_write> velocity [[texture(2)]],
                     constant SimUniforms& u                       [[buffer(0)]],
                     uint2 gid                                     [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;
    if (!isOnCanvas(float2(gid), u)) return;

    float2 cell = float2(gid);
    float2 here = u.pourPos * float2(u.gridSize);
    float2 r    = cell - here;
    float  dist = length(r);
    if (dist < 0.5f || dist >= u.pourRadius) return;

    float2 outward = r / dist;
    float  falloff = 1.0f - dist / u.pourRadius;
    float  push    = falloff * 280.0f * u.toolForce;

    float4 vel = velocity.read(gid);
    vel.xy += outward * push;
    velocity.write(vel, gid);
}

// Thinner — removes density and injects a radially outward velocity impulse.
// Lower density = less buoyancy loading = paint responds faster to tilt.
// The outward impulse makes it visibly spread, like solvent hitting wet paint.
kernel void thinnerTool(texture2d<float, access::read_write> color    [[texture(0)]],
                        texture2d<float, access::read_write> density  [[texture(1)]],
                        texture2d<float, access::read_write> velocity [[texture(2)]],
                        constant SimUniforms& u                       [[buffer(0)]],
                        uint2 gid                                     [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float2 cellPos  = float2(gid);
    float2 toolCell = u.pourPos * float2(u.gridSize);
    float  dist     = length(cellPos - toolCell);
    if (dist >= u.pourRadius) return;

    float t        = 1.0f - dist / u.pourRadius;
    float strength = t * u.dt * 4.0f;

    float curDen = density.read(gid).r;
    density.write(float4(clamp(curDen - strength * 0.6f, 0.0f, 1.0f)), gid);

    float2 dir = (dist > 0.5f) ? normalize(cellPos - toolCell) : float2(1.0f, 0.0f);
    float4 vel = velocity.read(gid);
    vel.xy += dir * strength * 5.0f;
    float spd = length(vel.xy);
    if (spd > 50.0f) vel.xy = normalize(vel.xy) * 50.0f;
    velocity.write(vel, gid);
}

// Thickener — adds density and dampens velocity.
// Higher density = more gravity loading, slower response, paint pools in place.
kernel void thickenerTool(texture2d<float, access::read_write> color    [[texture(0)]],
                          texture2d<float, access::read_write> density  [[texture(1)]],
                          texture2d<float, access::read_write> velocity [[texture(2)]],
                          constant SimUniforms& u                       [[buffer(0)]],
                          uint2 gid                                     [[thread_position_in_grid]])
{
    if (!u.pourActive) return;
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    float2 cellPos  = float2(gid);
    float2 toolCell = u.pourPos * float2(u.gridSize);
    float  dist     = length(cellPos - toolCell);
    if (dist >= u.pourRadius) return;

    float t        = 1.0f - dist / u.pourRadius;
    float strength = t * u.dt * 4.0f;

    float curDen = density.read(gid).r;
    density.write(float4(clamp(curDen + strength * 0.8f, 0.0f, 1.5f)), gid);

    float4 vel = velocity.read(gid);
    vel.xy *= max(1.0f - strength * 0.5f, 0.0f);
    velocity.write(vel, gid);
}

// ---------------------------------------------------------------------------
// 4. Advect — semi-Lagrangian backtrace for any float4 field
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// fillCanvas — flood-fill the entire grid with a solid base color.
// Called once at canvas init; uses injectR/G/B from uniforms as the base color.
// ---------------------------------------------------------------------------
kernel void fillCanvas(texture2d<float, access::write> color   [[texture(0)]],
                       texture2d<float, access::write> density [[texture(1)]],
                       constant SimUniforms& u                  [[buffer(0)]],
                       uint2 gid                               [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;
    float3 lab = rgbToOklab(float3(u.injectR, u.injectG, u.injectB));
    color.write(float4(lab, 1.0), gid);
    // On-canvas cells start with full density; the table has zero mass.
    float d = isOnCanvas(float2(gid), u) ? 1.0 : 0.0;
    density.write(float4(d, 0.0, 0.0, 0.0), gid);
}

kernel void advect(texture2d<float, access::read>        velocity [[texture(0)]],
                   texture2d<float, access::sample>      fieldIn  [[texture(1)]],
                   texture2d<float, access::write>       fieldOut [[texture(2)]],
                   constant SimUniforms& u                        [[buffer(0)]],
                   uint2 gid                                      [[thread_position_in_grid]])
{
    if (gid.x >= u.gridSize.x || gid.y >= u.gridSize.y) return;

    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 gridSizeF = float2(u.gridSize);

    // Off-canvas handling depends on advectMode:
    //   1 (extrude — color & density): mirror the nearest on-canvas cell so
    //       linear sampling at the boundary doesn't bleed base color in.
    //   0 (freeze — velocity):        keep zero so the pressure-solve sees a
    //       clean boundary and we don't push paint outside the canvas.
    if (!isOnCanvas(float2(gid), u)) {
        if (u.advectMode == 1) {
            float2 projected = float2(gid);
            if (u.canvasIsRound != 0) {
                float2 c = float2(u.canvasMinX + u.canvasMaxX,
                                  u.canvasMinY + u.canvasMaxY) * 0.5;
                float r = (u.canvasMaxX - u.canvasMinX) * 0.5 - 0.6;
                float2 dir = projected - c;
                float  len = max(length(dir), 1e-4);
                projected = c + dir * (min(len, r) / len);
            } else {
                projected.x = clamp(projected.x,
                                    u.canvasMinX + 0.5, u.canvasMaxX - 0.5);
                projected.y = clamp(projected.y,
                                    u.canvasMinY + 0.5, u.canvasMaxY - 0.5);
            }
            float2 projUV = projected / gridSizeF;
            fieldOut.write(fieldIn.sample(s, projUV), gid);
        } else {
            fieldOut.write(fieldIn.read(gid), gid);
        }
        return;
    }

    float2 uv  = (float2(gid) + 0.5) / gridSizeF;
    float2 vel = velocity.read(gid).xy;

    // Static-friction skip: below this velocity the cell is considered "at
    // rest" and we copy it through unchanged. This prevents the linear
    // sampler from imperceptibly blurring colors every frame — over a
    // minute that blur is what was draining the painting to grey.
    if (length(vel) < 0.3) {
        fieldOut.write(fieldIn.read(gid), gid);
        return;
    }

    // Backtrace position in UV space.
    float2 prevUV  = uv - vel * u.dt / gridSizeF;
    float2 prevPix = prevUV * gridSizeF;

    // If the back-trace lands off the canvas (e.g. a border cell whose
    // velocity points outward), clamp it to the nearest interior cell
    // instead of freezing. This stops the visible "base-color band" at
    // the edges and lets paint actually flow up to the boundary.
    if (!isOnCanvas(prevPix, u)) {
        if (u.canvasIsRound != 0) {
            float2 c = float2(u.canvasMinX + u.canvasMaxX,
                              u.canvasMinY + u.canvasMaxY) * 0.5;
            float r = (u.canvasMaxX - u.canvasMinX) * 0.5 - 0.6;
            float2 dir = prevPix - c;
            float  len = max(length(dir), 1e-4);
            prevPix = c + dir * (min(len, r) / len);
        } else {
            prevPix.x = clamp(prevPix.x,
                              u.canvasMinX + 0.5, u.canvasMaxX - 0.5);
            prevPix.y = clamp(prevPix.y,
                              u.canvasMinY + 0.5, u.canvasMaxY - 0.5);
        }
        prevUV = prevPix / gridSizeF;
    }

    prevUV = clamp(prevUV, 0.5 / gridSizeF, 1.0 - 0.5 / gridSizeF);
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

    // Table surface around the canvas — color picked to contrast with the
    // user's chosen base color so the canvas always pops:
    //   light base (luma > 0.5) → dark granite table
    //   dark  base (luma ≤ 0.5) → light off-white plastic-folding-table
    float2 pixelPos = in.uv * float2(u.gridSize);
    if (!isOnCanvas(pixelPos, u)) {
        // Distance from canvas edge, used for the soft contact shadow.
        float edgeDist;
        if (u.canvasIsRound != 0) {
            float2 c = float2(u.canvasMinX + u.canvasMaxX,
                              u.canvasMinY + u.canvasMaxY) * 0.5;
            float r = (u.canvasMaxX - u.canvasMinX) * 0.5;
            edgeDist = distance(pixelPos, c) - r;
        } else {
            float dx = max(u.canvasMinX - pixelPos.x, pixelPos.x - u.canvasMaxX);
            float dy = max(u.canvasMinY - pixelPos.y, pixelPos.y - u.canvasMaxY);
            edgeDist = max(dx, dy);
        }

        // WCAG-ish base-color luminance (linear approximation good enough here)
        float baseLum = dot(float3(u.baseR, u.baseG, u.baseB),
                            float3(0.2126, 0.7152, 0.0722));

        float3 table;
        if (baseLum > 0.5) {
            // Dark granite. Hash-noise speckles give it crystalline grit.
            float3 graniteBase = float3(0.14, 0.13, 0.135);
            float h = fract(sin(dot(pixelPos, float2(12.9898, 78.233))) * 43758.5453);
            // Tiny clusters of darker / lighter flecks
            float fleck = (h - 0.5) * 0.18;
            float h2 = fract(sin(dot(pixelPos * 0.5, float2(39.3468, 11.135))) * 25731.231);
            if (h2 > 0.985) fleck += 0.15;          // rare bright crystal
            else if (h2 < 0.02) fleck -= 0.08;      // rare dark vein
            table = clamp(graniteBase + fleck, 0.04, 0.35);
        } else {
            // Light off-white plastic folding table — slightly warm.
            float3 plasticBase = float3(0.94, 0.93, 0.89);
            // Very faint horizontal banding so it doesn't look flat-CGI
            float band = sin(pixelPos.y * 0.07) * 0.012;
            table = clamp(plasticBase + band, 0.0, 1.0);
        }

        // Soft contact shadow under the canvas edge (~8-cell band)
        float shade = saturate(1.0 - edgeDist / 8.0);
        table *= 1.0 - shade * 0.35;
        return float4(table, 1.0);
    }

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
