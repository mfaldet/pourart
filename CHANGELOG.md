# Changelog

All notable changes per milestone. Format: date · scope · description.

---

## M0 — Sim Spike (in progress)

- 2026-05-18 · init · Repository initialized; SPEC.md, CLAUDE.md, DECISIONS.md, CHANGELOG.md created
- 2026-05-18 · spike · PourSimSpike Xcode project scaffolded with single-color Stable Fluids Metal shaders, MTKView wrapper, CoreMotion gravity integration, and toggleable debug overlay

**M0 result:** 60 fps locked, phone stayed cold, all debug overlays functional. Gate passed 2026-05-23. See DECISIONS.md for full result table.

**Observation:** Sim behavior is too gaseous/watery. Pour paint is honey-viscous. Tuning required before M1 — documented in `docs/pour-painting-research.md §8`.

---

## Pre-M1 Research

- 2026-05-23 · research · `docs/pour-painting-research.md` created — thorough survey of pour painting physics, techniques, cell formation, color behavior, and sim tuning implications

---

## M1 — Multi-color + Oklab + Honey Viscosity (in progress)

- 2026-05-23 · sim · Viscosity tuning round 1: gravity scale 15→3, per-frame velocity damping (0.94×) added to `addForces`, viscosity coefficient 0.0001→0.0008, buoyancy uniform exposed (default 4.0). Sim should now feel honey-like rather than gaseous.
- 2026-05-23 · color · Grid color storage moved to Oklab. RGB→Oklab on pour injection, Oklab→RGB at render. Mixing math is now perceptually uniform — red+green should look like blended pigment, not muddy brown.
- 2026-05-23 · color · Fixed "ghost black" bug in source injection: empty cells (opacity=0) now properly snap to the injection color instead of lerping from (0,0,0) Oklab through dark intermediate shades.
- 2026-05-23 · ui · Ocean palette (5 swatches: Navy, Teal, Sky, Foam, Gold) added to top of canvas. Tap to select active pour color.
- 2026-05-23 · uniforms · `SimUniforms` extended with `injectR/G/B`, `damping`, `surfaceTension` (plumbed, not yet implemented), `buoyancy`. Swift struct layout verified against Metal layout.
- 2026-05-24 · sim · Surface tension kernel (`surfaceTensionForce`) implemented using the Continuum Surface Force (CSF) method: computes density gradient + Laplacian curvature, applies cohesive velocity force at color interfaces. Default coefficient 0.06. Creates lacing/beading at color boundaries.
- 2026-05-24 · input · Multi-touch pour implemented. Replaced `UIPanGestureRecognizer`/`UILongPressGestureRecognizer` with `TouchMTKView` subclass that overrides `touchesBegan/Moved/Ended/Cancelled` directly. Renderer now holds `pourPositions: [SIMD2<Float>]`; `FluidSimulator.step()` dispatches `addSources` once per active finger.

**M1 complete.** Next: M2 — tool model (Thinner, Thickener, Drop, Wipe).

---

## M2 — Tool Model & Toolbar (in progress)

- 2026-05-24 · sim · Four new Metal kernels: `dropTool` (3× density overshoot + outward impulse → cell seeding), `wipeTool` (gradual opacity/density erosion), `thinnerTool` (density reduction + outward velocity → solvent spread), `thickenerTool` (density increase + velocity damping → paint pools).
- 2026-05-24 · arch · `Tool` enum (Pour, Drop, Thinner, Thickener, Wipe) with per-tool radius, icon, and `usesColor` flag. Module-level visibility — used by FluidSimulator, Renderer, and ContentView.
- 2026-05-24 · sim · `FluidSimulator.step()` accepts `activeTool: Tool`; dispatches the matching kernel per finger. `pourRadius` uniform set per-tool (Drop=6, Thinner=20, Wipe=22, etc.).
- 2026-05-24 · ui · Bottom toolbar with icon + label per tool. Palette row animates in/out based on `usesColor`. Tool selection drives sim behavior live with no reinitialization.

**Next:** M3 — Palette & home screen (preset palettes, custom color picker, recents).

---

## M3 — Palette & Home Screen (in progress)

- 2026-05-24 · data · `PaletteModel.swift` added: `PaletteColor`, `Palette` (5 slots + SF Symbol icon), `PaletteStore` (ObservableObject). 6 preset palettes: Ocean, Sunset, Earth, Neon, Mono, Pastel.
- 2026-05-24 · data · Recents: last 10 custom colors persisted to UserDefaults as flat Float array. Deduplicated within 1/255 tolerance.
- 2026-05-24 · ui · `PalettePickerView`: list of all 6 presets with color-circle previews + checkmark on active. Recents section shows scrollable row of saved custom colors — tap to apply to current slot.
- 2026-05-24 · ui · `ColorSlotEditorView`: long-press any swatch in the canvas palette row → system HSL ColorPicker (iOS native) + recents quick-pick. "Set" saves to that slot and adds color to recents.
- 2026-05-24 · ui · `RootView` / `HomeView`: home screen with app title, active palette preview, "New Pour" and "Choose Palette" buttons. Canvas launched via state transition (no NavigationStack overhead).
- 2026-05-24 · arch · `CanvasContainerView` replaces `ContentView` as the canvas HUD wrapper. `injectColor` simplified from @Binding to plain value (PaletteStore is source of truth). Palette picker button (paintpalette.fill) added to left of swatch row.

**Next:** M4 — Finish flow & preview (frame/wall composite, save to Photos).

---

## M4 — Finish Flow & Preview (complete)

- 2026-05-24 · renderer · `captureImage()` added to `Renderer`: off-screen `.shared` MTLTexture, GPU render at drawable resolution, `getBytes` → BGRA→CGImage → UIImage. Blocking (one-time capture — acceptable).
- 2026-05-24 · canvas · `onRendererReady: ((Renderer) -> Void)?` callback wired through `CanvasView` and `Coordinator.setupRenderer` so `CanvasContainerView` holds a live renderer reference.
- 2026-05-24 · ui · Finish button added to top bar of `CanvasContainerView`. Confirm alert ("Finish Pour?") gates the capture.
- 2026-05-24 · ui · `PreviewView.swift` created: 5 frame styles (Minimal/White/Black/Gold/Wood — SwiftUI stroke overlays + CoreGraphics composite for export), 5 wall colors (Cream/Charcoal/Sage/Navy/Blush), pinch-to-zoom (`MagnificationGesture`), Save to Photos (`PHPhotoLibrary.requestAuthorization + UIImageWriteToSavedPhotosAlbum`), Share sheet (`UIActivityViewController`).
- 2026-05-24 · plist · `NSPhotoLibraryAddUsageDescription` added to `Info.plist`.

**M4 complete.** Next: M5 — AdMob interstitial, ATT prompt, frequency cap.

---

## M5 — Pre-Canvas Flow & Gallery (complete)

- 2026-05-24 · arch · Three-step `PourFlowView` introduced: step 0 IntentionView (vision + technique), step 1 PaletteBuilderView (color science), step 2 PaintSetupView (consistency, canvas shape, base color). Step 3 launches `CanvasContainerView`.
- 2026-05-24 · ui · `IntentionView.swift` — free-text intention prompt + 8 technique cards (Dirty Pour, Ring Pour, Dutch Pour, Flip Cup, Swipe, Tree Ring, String Pull, Bloom) with per-technique consistency/colors tips and an "Inspire Me" suggestion stub (keyword → heuristic for now).
- 2026-05-24 · ui · `PaintSetupView.swift` — per-color consistency mixers (thin/medium/thick), 4 canvas-shape options (Portrait/Landscape/Square/Round), 4 base-color presets + system ColorPicker for custom.
- 2026-05-24 · ui · `GalleryView.swift` — lazy 2-column thumbnail grid backed by `PaintingStore` (file-system JPEGs in Documents/paintings/). Tap → fullscreen pinch-zoom viewer; long-press → delete confirmation.
- 2026-05-24 · arch · `PourSession.swift` — `PourTechnique`, `CanvasShape`, `ColorHarmony` enums centralized for reuse across IntentionView, PaintSetupView, and PaletteBuilderView.

---

## M6 — Color Suite, Physics Overhaul, Tools (complete)

### M6a · Full-suite color control

- 2026-05-25 · color · `ColorTools.swift` — pure-function utilities: hex⇄RGB conversion, HSB⇄RGB, tints/shades/tones (lerp toward white/black/mid-gray), brightness/saturation/hue adjustments, WCAG luminance, legible-foreground picker, randomized palettes, k-means image extraction (drops near-black/near-white outliers, sorts by hue).
- 2026-05-25 · color · `PalettePresets.swift` — categorized library expanded from 6 → 35+ palettes across 6 categories: Classic, Nature, Mood, Artist-Inspired, Era, Cultural. `Palette.byCategory` provides sectioned access.
- 2026-05-25 · color · `PaletteSlotEditor.swift` — per-slot full editor: live preview with hex (foreground auto-flips by luminance), hex text input, custom `GradientSlider` for H/S/B (rainbow track, gray→pure, black→bright), 7-step Tints/Shades/Tones bars, RGB/HSB/Hex/Luma info tiles, color-blindness chips (Protan/Deutan/Tritan) using Brettel/Viénot 3×3 simulation.
- 2026-05-25 · color · `PhotoPickerSheet.swift` — `PHPickerViewController` wrapper (no library permission required). Selected image → k-means palette extraction → fills unlocked slots.
- 2026-05-25 · color · `PaletteBuilderView` re-architected with three modes (Harmony / Image / Custom), 5 lockable slot cells with hex labels and per-slot lock buttons, top action row (Load / Copy hex codes / Save), Match button (harmonizes unlocked from first locked color), Clear Locks, Adjust toolbar (3 vertical rocker pairs — Warmer/Cooler, Lighten/Darken, Saturate/Desaturate — plus a separated Reverse/Shuffle column), full-palette accessibility preview row, harmony-specific color-science tips.
- 2026-05-25 · data · `PaletteStore` extended with `savedPalettes: [Palette]` persisted as JSON to UserDefaults, `setBaseColor`, `selectNeutral` (sets `transientColor` published var for off-palette quick picks), `neutralPalette` constant (White/Black/two grays/Gold/Silver) for canvas-side accents.
- 2026-05-25 · ui · `PalettePickerView` reworked with category chip header (Classic/Nature/Mood/Artist/Era/Cultural/Saved) and `.swipeActions` delete on custom palettes.

### M6b · Simulator + physics overhaul

- 2026-05-25 · sim · **Canvas shape mask** — `SimUniforms.canvasMinX/Y/MaxX/Y/canvasIsRound` plumbed end-to-end (`FluidSimulator.applyCanvasShape`, `Renderer.applyCanvasShape`, threaded from `PourFlowView` through `CanvasContainerView`). New `isOnCanvas(p, u)` helper in Shaders.metal honored by every kernel: fillCanvas (off-canvas density = 0), addForces (zero velocity off-canvas), surfaceTension (skips off-canvas + treats off-canvas neighbors as own density to prevent fake gradients), addSources/swipeTool/stirTool (can't pour off-canvas), advect (extrude or freeze based on advectMode), renderFrag (draws table outside canvas).
- 2026-05-25 · sim · **Table rendering** — fragment shader draws a "table" surface around the canvas with a soft 8-cell contact shadow at the edge. Table color is content-aware: WCAG luminance > 0.5 → dark granite (hash-noise speckles + rare bright crystal / dark vein flecks), ≤ 0.5 → off-white plastic-folding-table (faint horizontal banding).
- 2026-05-25 · sim · **Tilt sensitivity tuned** — `MotionService.gravityScale` 3 → 60, `damping` 0.94 → 0.97, `buoyancy` 4 → 6, velocity clamp 50 → 200. Terminal flow speed at 90° tilt ≈ 200 cells/sec.
- 2026-05-25 · sim · **15° tilt deadzone** in MotionService — below 15° outputs exactly (0,0), above ramps smoothly to full strength at 90°. Real paint doesn't move on a flat-ish table.
- 2026-05-25 · sim · **Static-friction settle** in addForces — when gravity uniform is zero AND speed < 0.8, snap velocity to zero. Catches surface-tension oscillations at color boundaries.
- 2026-05-25 · sim · **Advect skip below 0.3 cells/sec** — was: linear sampler imperceptibly averaged each cell with neighbors every frame, draining vibrant paintings to grey within 30s. Now: low-velocity cells short-circuit (copy fieldIn(gid) → fieldOut(gid)), color preserved indefinitely on a flat surface.
- 2026-05-25 · sim · **Off-canvas extrusion** — `advect` with `advectMode = 1` (color/density) mirrors the nearest on-canvas cell off-canvas so the linear sampler at the boundary never reads base color into the painting. `advectMode = 0` (velocity) keeps freeze behavior for clean pressure-solve Dirichlet boundaries.
- 2026-05-25 · sim · **Border base-color bleed fix** — `advect` no longer freezes when prevPix lands off-canvas; it clamps to the nearest interior cell (rect via `clamp`, circle via radial projection). Paint flows up to the edge instead of leaving a visible base-color band.
- 2026-05-25 · sim · **Surface-tension fake-gradient fix** — boundary cells now mirror their own density when neighbors are off-canvas. Was creating an inward-pulling fake force at every canvas edge cell, distorting flow.
- 2026-05-25 · sim · **Hard-stamp pour** — `addSources` writes pure `injectLab` with opacity 1.0 in one frame (no falloff, no opacity-weighted blend). Color mixing happens *only* via advection now.
- 2026-05-25 · sim · **Surface tension default** 0.06 → 0.18 (more cohesive blobs). Consistency-driven range widened: thin {damping 0.99, viscosity 0.0001, ST 0.06} → thick {damping 0.82, viscosity 0.020, ST 0.40}.
- 2026-05-25 · sim · **Renderer pulls live uniforms** — `FluidSimulator.renderUniforms()` exposes the current uniform state (canvas bounds, base color, etc.) so the fragment shader sees the user's actual choices instead of `SimUniforms()` defaults. Same applies to `captureImage()` exports.

### M6c · Input

- 2026-05-25 · input · **Pressure-driven pour width** — `TouchMTKView.radius(for:)` prefers `touch.force / touch.maximumPossibleForce` (Apple Pencil + older 3D-Touch), falls back to `touch.majorRadius` (every iPhone). Mapped through `pow(p, 1.7)` so light taps ≈ pinprick, hard presses ≈ 4 cells. minPourRadius 1.0 → 0.1, maxPourRadius 40 → 4.0 (10× smaller than prior iteration).
- 2026-05-25 · input · **Coalesced touches** — `event.coalescedTouches(for: touch)` captures 240 Hz internal samples. Each becomes its own `PourTouch` so fast drags stay continuous instead of dotted.
- 2026-05-25 · input · **Swept-segment stamping** — `distToTouchSegment` helper in Shaders.metal treats each tool sample as a capsule from previous sample to current. `addSources`, `swipeTool`, `wipeTool` use it. Fast drags now produce continuous strokes; stir intentionally stays a point.
- 2026-05-25 · input · **Touch Y-flip removed** — `1 - pt.y / h` was wrong; UIKit, Metal texture sampling, and the fragment shader UV table all agree on top-down Y.
- 2026-05-25 · input · **Live gravity polling** — `Renderer` holds a weak `motionService` reference and reads `motionService?.gravity` every frame in `draw(in:)`. Previously gravity was only forwarded inside the `onTouchesChanged` callback, so paint wouldn't respond to tilt unless the user was actively touching the screen.
- 2026-05-25 · input · `PourTouch.drag: SIMD2<Float>` added — UV-space drag vector per sample. Powers swipe/stir/string and the swept-segment math.

### M6d · Tool system

- 2026-05-25 · tools · `Tool` enum reduced to `.pour, .swipe, .stir, .string, .balloon, .air, .cup` (7 tools). The earlier `.drop/.thinner/.thickener` were removed; `.wipe` was removed in M6f (kernel kept as unreferenced future scaffolding).
- 2026-05-25 · tools · `ToolVariant` struct (id, name, icon, radius, force) + variants list per tool — 21 variants total. Each tool maps to a kernel:
  - Pour / Balloon / Cup → `addSources`
  - Swipe / String → `swipeTool`
  - Stir → `stirTool`
  - Air → new `blowTool` (radial outward velocity, no paint injection)
- 2026-05-25 · tools · `SimUniforms.toolForce` — variant-driven force multiplier so e.g. Compressor (force 2.0) hits twice as hard as Hair Dryer (force 1.0) at the same falloff.
- 2026-05-25 · tools · Per-tool variant memory — `CanvasContainerView.toolVariants: [Tool: ToolVariant]` preserves the user's variant choice when switching between tools.

### M6e · Canvas HUD layout

- 2026-05-25 · ui · Top-of-canvas chrome hugged to status-bar safe area: `ToolSelectorButton` (pill menu with all 7 tools) + ellipsis menu (Finish & Preview / Exit Without Saving).
- 2026-05-25 · ui · Bottom-of-canvas secondary nav is **tool-specific**:
  - Pour → palette capsule (palette button + 5 swatches + neutral toggle)
  - Balloon / Cup → variant chips + palette capsule
  - Swipe / Stir / String / Air → variant chips only
- 2026-05-25 · ui · Neutral row expands above the swatch capsule when toggled (chevron flips up/down). Chevron points up when collapsed (will expand upward), down when expanded (will collapse downward).
- 2026-05-25 · ui · ToolSelectorButton chevron points down (menu opens downward now that it's at the top).

### M6f · Late polish

- 2026-05-25 · tools · `Wipe` removed entirely (user feedback — "you can't erase paint"). `.wipe` enum case gone, `psWipeTool` pipeline removed, `.wipe` case removed from dispatch switch. The `wipeTool` kernel stays in Shaders.metal as dead code, earmarked for the real cell-medium-dipped "wipe technique" implementation later.
- 2026-05-25 · ui · `BalanceTestView.swift` — tilt diagnostic mini-game. Tap the `t` button bottom-right on the home screen → tap anywhere to spawn a 3D-shaded red marble → tilt the phone to roll it (1800 pt/s² per unit gravity, 0.985 rolling friction, 0.55 wall bounce elasticity). Own `BallMotion` class with a ~3° deadband so the test reacts to slight tilts independent of the canvas's 15° deadzone.
- 2026-05-25 · docs · `ARCHITECTURE.md` written — comprehensive technical walkthrough: project layout, end-to-end user flow, sim pipeline (grid + textures, per-frame ordering, coordinate spaces, canvas mask, Oklab color storage, hard-stamp pour, static-friction settle, swept-segment stamping, tool catalog), input pipeline (TouchMTKView + MotionService), color & palette system, tilt/balance test, persistence, rendering & framing, build notes, conventions/quirks.

**M6 complete.** Next: M7 — TestFlight beta · AdMob / ATT prompt · onboarding · session thumbnail in gallery + palette + technique metadata.
