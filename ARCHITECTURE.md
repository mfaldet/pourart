# Pour Art — Architecture

A thorough technical walkthrough of how the app fits together as of M6.
Companion to `SPEC.md` (what the product does) and `CHANGELOG.md` (when each
piece landed). Read this when you need to understand *why* a system works
the way it does.

---

## 1. Project layout

```
pourart/
├── ARCHITECTURE.md           ← this file
├── CHANGELOG.md              ← chronological log per milestone
├── CLAUDE.md                 ← agent workflow rules
├── DECISIONS.md              ← gate review notes (M0, M1, …)
├── SPEC.md                   ← product spec
├── docs/
│   └── pour-painting-research.md
└── PourSimSpike/
    ├── PourSimSpike.xcodeproj/…
    └── PourSimSpike/
        ├── Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
        ├── BalanceTestView.swift
        ├── CanvasView.swift
        ├── ColorTools.swift
        ├── ContentView.swift
        ├── FluidSimulator.swift
        ├── GalleryView.swift
        ├── Info.plist
        ├── IntentionView.swift
        ├── MotionService.swift
        ├── PaintSetupView.swift
        ├── PaletteBuilderView.swift
        ├── PaletteModel.swift
        ├── PalettePresets.swift
        ├── PaletteSlotEditor.swift
        ├── PhotoPickerSheet.swift
        ├── PourFlowView.swift
        ├── PourSession.swift
        ├── PourSimSpikeApp.swift
        ├── PreviewView.swift
        ├── Renderer.swift
        └── Shaders.metal
```

Every Swift file (and the Metal file) is in the build via `project.pbxproj`.
The build target is iOS 17+ (uses SwiftUI `onChange(of:_:_:)` two-arg form,
`Menu` content closures, `.fullScreenCover(item:)`, `ScrollView`
`showsIndicators`, etc.).

---

## 2. End-to-end user flow

```
PourSimSpikeApp                       ← app entry
   └─ RootView                        ← navigation root
       ├─ HomeView                    ← wordmark, palette preview, "New Pour" / "See My Art" / "t"
       │   ├─ → PourFlowView          ← 3-step pre-canvas flow
       │   │     ├─ step 0  IntentionView    ← vision + technique
       │   │     ├─ step 1  PaletteBuilderView ← Harmony / Image / Custom
       │   │     ├─ step 2  PaintSetupView    ← canvas shape, base color, per-color consistency
       │   │     └─ step 3  CanvasContainerView ← the simulator
       │   ├─ → GalleryView                ← saved paintings (file-system store)
       │   └─ → BalanceTestView            ← tilt diagnostic mini-game
       └─ Sheets: PalettePickerView, PreviewView (from canvas)
```

The flow is deliberately step-based: an artist picks an *intention* first,
then *colors*, then *materials* (consistency, base, canvas shape), and only
then enters the canvas. This mirrors how a real pour painter prepares.

---

## 3. The simulation pipeline

This is the heart of the app. All visible motion comes from a 2D
incompressible-fluid solver running entirely on the GPU (`Shaders.metal`),
driven by `FluidSimulator.swift`.

### 3.1 Grid + textures

Fixed grid `256 × 576` (portrait aspect). Five ping-pong texture pairs:

| Pair             | Pixel format    | Channels                             |
| ---------------- | --------------- | ------------------------------------ |
| `colorA/B`       | `.rgba16Float`  | Oklab `L, a, b` in `.xyz`, opacity `.w` |
| `velocityA/B`    | `.rg16Float`    | `x`, `y` velocity in cells / sec     |
| `densityA/B`     | `.r16Float`     | local paint mass (0 off-canvas, 1 on-canvas, 1.2 freshly poured) |
| `pressureA/B`    | `.r16Float`     | scalar pressure                      |
| `divergenceTex`  | `.r16Float`     | scratch space for divergence         |

All `private` storage; CPU only writes them via the `fillCanvas` kernel.

### 3.2 Per-frame pipeline (in `FluidSimulator.step()`)

```
1. addForces            (vel)   — damp, gravity, static-friction snap
2. surfaceTension       (vel)   — CSF cohesion at density gradients
3. tool kernel          (varies) — pour / swipe / stir / blow per finger
4. advect velocity      (vel)   — semi-Lagrangian backtrace
5. diffuse velocity     (×20)   — Jacobi iteration for viscosity
6. divergence           (∇·v)   — scratch into divergenceTex
7. pressure solve       (×35)   — Jacobi iteration
8. subtractGradient     (vel)   — make velocity divergence-free
9. advect color         (col)   — extrudes off-canvas
10. advect density       (den)   — extrudes off-canvas
```

Each numbered stage is one Metal compute dispatch (with the Jacobi loops
ping-ponging their pair on each iteration).

### 3.3 Coordinate spaces

Three coordinate systems are involved; getting them straight is essential:

| Space      | Range            | Used in                              |
| ---------- | ---------------- | ------------------------------------ |
| Cell       | `[0, gridSize)`  | inside compute kernels — `gid`        |
| UV         | `[0, 1]`         | `pourPos` uniform, fragment `in.uv`   |
| Screen     | `[0, viewSize)`  | `UITouch.location(in:)`               |

The fragment shader's vertex UV table places `uv.y = 0` at the **top** of
the screen (matching `in.position` of `+1` at top). Hence the simulator's
y axis is also top-down. Touch coordinates from UIKit are top-down too, so
**no Y flip** is needed in `TouchMTKView`. (We had a `1 - pt.y / h` bug
early on; it's gone now.)

### 3.4 Canvas mask

The simulator always uses the full `256×576` grid, but the visible canvas
is a centered sub-region defined by uniform fields:

```c
float canvasMinX, canvasMinY, canvasMaxX, canvasMaxY;
uint  canvasIsRound;          // 0 = rect, 1 = circle
```

`isOnCanvas(p)` is checked in every kernel that touches paint. Cells off
the canvas:

- Never accept pours (`addSources` early-returns)
- Never feel forces (`addForces` zeroes velocity, `surfaceTension`
  early-returns)
- Mirror the nearest on-canvas cell during color/density `advect`
  (`advectMode = 1`, "extrude") so the linear sampler at the boundary
  never reads black base into the painting
- For velocity `advect` (`advectMode = 0`, "freeze"), they keep
  whatever value was there — usually 0 — so the pressure-solve sees
  clean Dirichlet boundary conditions

The fragment shader paints the off-canvas region as the **table** —
dark granite when the base color is light, off-white plastic-folding-table
when the base color is dark (WCAG luminance threshold of 0.5). Both
table surfaces use procedural per-pixel hash noise (granite speckle, faint
plastic banding) plus an 8-cell soft contact shadow at the canvas edge.

### 3.5 Color storage: Oklab

Paint colors live in the grid as **Oklab** (Björn Ottosson, 2020) rather
than sRGB. Reason: linear interpolation of two sRGB values produces
"muddy brown" mixes (perceptually wrong); Oklab interpolation gives
visually correct pigment-like mixing.

- `rgbToOklab(rgb)` and `oklabToRgb(lab)` live near the top of
  `Shaders.metal`. They're called once at pour time (RGB → Oklab into
  `colorTex`) and once at render time (Oklab → RGB in `renderFrag`).
- The advection step (which dominates color changes) operates directly on
  Oklab, so every interpolated cell is a perceptual blend.

### 3.6 Hard-stamp pour, advection-only mixing

The `addSources` kernel writes `float4(injectLab, 1.0)` and
`density = 1.2` inside the swept-segment radius — **no opacity blend, no
falloff at the edge**. This was an explicit design decision: real wet
paint poured onto a surface has a hard boundary at the rim; mixing only
happens as the paint flows.

After the pour stamp lands, *all blending* comes from advection (linear
sampling in Oklab while velocity carries colors around). Tilting,
swiping, stirring — these create velocity, which carries paint and
naturally produces the gradient/streak/cell effects.

### 3.7 Static-friction settle

Real acrylic paint at rest on a flat table doesn't move. The sim
respects this in three places:

1. **`MotionService`** applies a 15° tilt deadzone. Below 15°, raw
   gravity → exactly `(0,0)`. Above 15°, a smooth ramp from 0 to full
   strength at 90°.
2. **`addForces`** snaps velocity to zero when `length(gravity) < 0.1`
   AND `speed < 0.8`. Surface-tension forces oscillate every frame at
   color boundaries; this catches them.
3. **`advect`** short-circuits any cell whose velocity magnitude is
   `< 0.3`. Without this, the linear sampler would imperceptibly average
   each cell with its neighbors on every frame — over a minute the
   accumulated blur would drain a vibrant painting to grey. Now: vel ≈
   0 → cell freezes → color preserved indefinitely.

The combined effect: phone on a flat table = paint completely frozen, no
drift, no fade, no perceptible change for as long as you leave it.

### 3.8 Swept-segment tool stamping

Each tool dispatch treats the touch sample as a **capsule** along the
segment from the *previous* coalesced sample (`pourPos - drag`) to the
*current* one (`pourPos`). The shader helper:

```c
distToTouchSegment(p, u, gridSize)  // closest distance from p to segment
```

is used by `addSources`, `swipeTool`, and `wipeTool` (kernel still in
the file, currently unreferenced) so that fast drags produce **continuous
strokes** rather than dotted breadcrumbs. At 240 Hz internal coalesced
sampling a swift swipe is ~4 samples per frame; each one paints its
capsule, capsules connect end to end.

Stir intentionally **does not** use segment distance — it's a swirl at
the finger, not a stroke.

### 3.9 Tool catalog

Seven tools (`Tool` enum in `ContentView.swift`):

| Tool    | Kernel(s)    | Purpose                                                              |
| ------- | ------------ | -------------------------------------------------------------------- |
| Pour    | `addSources` | Inject active color (per-touch pressure radius)                       |
| Swipe   | `swipeTool`  | Drag the velocity field — palette-knife streaks                       |
| Stir    | `stirTool`   | Rotational velocity around finger — swirls/whirlpools                 |
| String  | `swipeTool`  | Reuses swipe with narrow radius / variant settings                    |
| Balloon | `addSources` | Pours with very large radii (color picker shows)                      |
| Air     | `blowTool`   | Radial outward velocity — hair dryer / compressor / straw             |
| Cup     | `addSources` | Huge radius pour                                                      |

Each tool has 3-4 **variants** (`ToolVariant` struct) — palette knife
shape, string thickness, balloon size, air source, cup style. Variants
override the tool's `radius` and an additional `toolForce` multiplier
(both pushed to the shader via uniforms).

The selected variant for each tool is stored in
`CanvasContainerView.toolVariants: [Tool: ToolVariant]`, so switching
Stir → Pour → Stir restores your last Stir choice.

---

## 4. Input pipeline

### 4.1 Touch — `TouchMTKView`

A `MTKView` subclass that overrides `touchesBegan/Moved/Ended/Cancelled`
directly. `UIGestureRecognizer` can't track multiple simultaneous touches
at the precision we need; the raw `UITouch` API can.

For each `UITouch` we read **`event.coalescedTouches(for: touch)`** —
this returns every sub-frame sample iOS captured (up to 240 Hz on
ProMotion devices). Each sub-sample becomes one `PourTouch`:

```swift
struct PourTouch {
    let pos:    SIMD2<Float>     // UV [0,1]
    let radius: Float            // cells — derived from touch.force or .majorRadius
    let drag:   SIMD2<Float>     // pos - previous UV (for swept-segment stamping)
}
```

The radius comes from pressure:
- Prefer `touch.force / touch.maximumPossibleForce` (Apple Pencil, older
  3D-Touch iPhones)
- Otherwise `touch.majorRadius` — every iPhone reports the physical
  contact-area radius (~4 pt light tap → ~20 pt hard press)
- Mapped through `pow(p, 1.7)` so light taps stay small (~0.3 cells)
  and only hard presses reach the maximum (4 cells)

### 4.2 Motion — `MotionService` (and `BallMotion`)

Both wrap `CMMotionManager.startDeviceMotionUpdates(to:)` and publish a
2D gravity vector as `@Published`. The pipeline:

1. Raw gravity → flip Y (CoreMotion's Y is device-up; we want screen-down)
2. Compute magnitude
3. If `mag < deadzone`, output zero
4. Else, smooth-ramp by `(mag - deadzone) / (1 - deadzone)` and scale by
   `gravityScale`

`MotionService` (used by the canvas) has a **15° deadzone** so real
paint settles on a flat-ish table. `BallMotion` (used by the balance
test) has a **~3° deadzone** so the test ball reacts to small tilts.

Critically, **the `Renderer` pulls gravity from `motionService` every
single frame in `draw(in:)`**, not from a touch callback. This is what
makes tilt instantly responsive whether you're touching the screen or
not.

---

## 5. Color & palette system

### 5.1 The data model (`PaletteModel.swift`)

```swift
struct PaletteColor   { id, name, rgb: SIMD3<Float> }
struct Palette        { id, name, icon, category: PaletteCategory, colors: [5] }
enum   PaletteCategory { classic, nature, mood, artist, era, cultural, custom }
class  PaletteStore: ObservableObject {
    @Published var activePalette
    @Published var activeColorIndex
    @Published var transientColor: SIMD3<Float>?   // off-palette neutral
    @Published var recentColors:   [PaletteColor]  // last 10, persisted
    @Published var savedPalettes:  [Palette]       // user-saved, persisted (JSON)
    @Published var baseColor:      SIMD3<Float>    // canvas fill, persisted

    static let basePresets       = [White, Cream, Lt. Gray, Black]
    static let neutralPalette    = [White, Black, Lt. Gray, Dk. Gray, Gold, Silver]
}
```

`activeColor` is computed: `transientColor ?? activePalette[activeColorIndex].rgb`.
Tapping any neutral writes to `transientColor`; tapping a palette swatch
clears it.

### 5.2 Preset library (`PalettePresets.swift`)

35+ curated 5-color palettes across 6 categories:

- **Classic** — Ocean, Sunset, Earth, Neon, Mono, Pastel, Galaxy, Aurora, Marble, Lava, Pearl
- **Nature** — Forest, Coral Reef, Cherry Blossom, Autumn, Lavender, Stormy Sky, Desert, Tropical
- **Mood** — Calm, Energetic, Romantic, Mysterious, Joyful, Dramatic
- **Artist** — Monet, Van Gogh, Klimt, Picasso, Rothko, Frida
- **Era** — 70s Earth, 80s Synthwave, 90s Pastel, Y2K, Cyberpunk
- **Cultural** — Japanese Spring, Moroccan, Scandinavian, Mediterranean

Each is defined inline as hex codes via tiny helpers (`c()`, `P()`,
`hex()`). Saved custom palettes live in `.custom` and are loaded from
`UserDefaults` JSON.

### 5.3 The Palette Builder (`PaletteBuilderView.swift`)

Three modes:

- **Harmony** — color wheel + 6 harmony rules (analogous, complementary,
  split-comp, triadic, tetradic, monochromatic) + HSB sliders
- **Image** — `PHPickerViewController` (`PhotoPickerSheet.swift`) → 5-color
  k-means extraction (`ColorTools.extractPalette`)
- **Custom** — usage-tip card; tap any slot to open
  `PaletteSlotEditor`

Always-visible bottom area:

- **5 slot cells** with hex below each, lock button top-right (locked slots
  are immune to Randomize / Match / harmony regen)
- **Quick actions** — Randomize, Match (harmonize unlocked from
  first-locked color), Clear Locks
- **Adjust toolbar** — 4 stacked rocker pairs:
  - Warmer / Cooler  (hue rotate ±20°)
  - Lighten / Darken (brightness ±8%)
  - Saturate / Desaturate (saturation ±12%)
  - Reverse / Shuffle (positional, locks follow)
- **Accessibility preview** — three rows showing the whole palette
  simulated as protanopia / deuteranopia / tritanopia
- **Color science card** — harmony-specific pour-painting tip

### 5.4 Per-slot editor (`PaletteSlotEditor.swift`)

Full HSB editing for one slot:

- 120pt live preview with hex over the color (foreground auto-flips
  black/white via WCAG luminance check)
- Hex text input with "Apply" button
- Custom `GradientSlider` for Hue (rainbow track), Saturation (gray →
  pure), Brightness (black → bright)
- Tints / Shades / Tones — 7-step gradient bars; tap any swatch to set
- Color info tiles: RGB, HSB, Hex, Luma
- Color-blindness chips: Normal / Protan / Deutan / Tritan side by side

### 5.5 Color tools (`ColorTools.swift`)

Pure-function utilities:

- `hex(rgb)` / `rgb(fromHex:)` (handles `#FFF` and `#FFFFFF`)
- `hsb(from:)` / `rgb(h:s:b:)`
- `tints/shades/tones(of:count:)` — lerp toward white / black / 0.5 gray
- `adjustBrightness/Saturation/Hue` — single-channel deltas
- `luminance(rgb)` — WCAG relative luminance (linearized + Rec. 709
  weights)
- `legibleForeground(rgb)` — black or white, whichever contrasts the
  background
- `randomPalette(harmony:)` — random base hue → harmony rule
- `extractPalette(from image:, count:)` — k-means in linear RGB, drops
  near-black/near-white outliers, sorts result by hue
- `simulate(rgb, type:)` — Brettel/Viénot 3×3 matrix transform for color
  blindness simulation

---

## 6. Tilt & balance — `BalanceTestView.swift`

A standalone tilt diagnostic. Tap the `t` button bottom-right on the
home screen to open it.

- Dark "table" arena with a thin border
- Tap to spawn a 3D-shaded red marble
  (`RadialGradient` offset to top-left + drop shadow)
- 60 Hz timer drives physics:
  - `acceleration = gravity × 1800 pt/s²`
  - Position += velocity × dt
  - Velocity *= 0.985 per frame (rolling friction)
  - Bounce off all four walls (0.55 elasticity)
  - If gravity is in deadband AND |velocity| < 6, snap velocity to zero
- Own `BallMotion` class (3° deadband) so the canvas's
  `MotionService` is untouched

Purpose: instant sanity check that tilt input is reaching the simulator
in real time. If the ball moves, the canvas paint will too.

---

## 7. Persistence

| What                | Where                                       |
| ------------------- | ------------------------------------------- |
| Recent colors       | `UserDefaults` key `pourart.v1.recentColors`  |
| Base color          | `UserDefaults` key `pourart.v1.baseColor`     |
| Saved palettes      | `UserDefaults` key `pourart.v1.savedPalettes` (JSON) |
| Finished paintings  | Documents `paintings/painting_<UUID>.jpg`      |

`PaintingStore` (in `GalleryView.swift`) handles disk-side painting
persistence — sorted by file creation date, deleted by swipe action in
the gallery.

---

## 8. Rendering & framing

`Renderer.draw(in:)` runs the simulator step, then a fullscreen vertex
+ fragment pass that samples `colorTex` in Oklab, converts to RGB, mixes
with the cached canvas color by paint opacity, and adds a tiny density-
based gloss highlight. Off-canvas pixels go down the table-rendering
branch.

`Renderer.captureImage()` reruns the same fragment pass into a
`.shared`-storage `MTLTexture`, blocks (`waitUntilCompleted`), and
converts the raw BGRA bytes to a `UIImage` via `CGImage`. This is
called once when the user taps Finish.

`PreviewView` then composites the captured image with:

- 5 frame styles (Minimal / White / Black / Gold / Wood — SwiftUI strokes
  for live preview, CoreGraphics strokes for the export composite)
- 5 wall colors as a background
- Pinch-to-zoom, Save to Photos (`PHPhotoLibrary.requestAuthorization` →
  `UIImageWriteToSavedPhotosAlbum`), Share sheet
  (`UIActivityViewController`)
- Auto-save to the in-app gallery (`PaintingStore.save`)

---

## 9. Build / project notes

- Single target, iOS 17+ deployment
- Metal shaders in one file: `Shaders.metal`
- All Swift files are flat in `PourSimSpike/PourSimSpike/`, no folders
- Assets: only `AppIcon.appiconset` matters
- `Info.plist` declares:
  - `CFBundleDisplayName` = "Pour Art"
  - `NSMotionUsageDescription` — required for `CMMotionManager`
  - `NSPhotoLibraryAddUsageDescription` — required for save-to-Photos
  - `UISupportedInterfaceOrientations` = Portrait only

---

## 10. Conventions & quirks worth remembering

- **No Y flip in touch.** UIKit, Metal textures (default sample
  convention), and the fragment shader's UV table all agree on top-down
  Y. We had a buggy `1 - pt.y/h` early on; it's gone.
- **Hard stamp on pour.** Hard boundary, no edge falloff. Blending
  happens via advection.
- **Static friction is essential.** Without the deadzone +
  advect-skip-below-0.3, every painting drains to grey within ~30s.
- **`Renderer` polls gravity every frame.** Tilt is not tied to touch.
- **Off-canvas cells extrude.** Color/density `advect` mirrors the
  nearest on-canvas cell off-canvas so the linear sampler at the canvas
  edge doesn't bleed black (or base color) into the painting.
- **Pressure-driven pour width.** Touch radius is `pow(p, 1.7)` mapped
  from `touch.force` (or `majorRadius` fallback) — light taps stay
  pinprick-thin, hard presses go to ~4 cells.
- **`SimUniforms` Swift layout must match Metal struct exactly.** Append
  new fields to the end only.
- **The Wipe kernel is dead code** — no enum case, no pipeline state,
  no dispatch. Kept in `Shaders.metal` for the eventual real "wipe with
  cell-medium-dipped tool" implementation (which is a different
  algorithm — actual cell formation).
