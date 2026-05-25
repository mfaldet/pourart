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
