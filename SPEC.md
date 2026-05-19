# Pour Paint — Product & Engineering Spec
**Working title:** Pour (placeholder — see naming notes at end)
**Platform:** iOS only (SwiftUI + Metal)
**Sim approach:** Real 2D fluid simulation (Eulerian Stable Fluids, multi-color)
**Monetization:** Interstitial ads gated to the "finish / save" action
**Spec status:** v0.1 — pre-build refinement

---

## 1. Executive Summary

A tactile, physics-driven pour-painting simulator. The user tips paint onto a phone-screen canvas, tilts the device to direct flow under simulated gravity, plays with viscosity (thinners/thickeners) and color interactions, then previews the finished piece framed and hung on a wall. Two audiences converge on the same app: people who want a beautiful custom wallpaper made by their own hand, and people who want to rehearse real pour-painting techniques cheaply before buying $80 of resin and pigment.

The technical hook is **a real fluid sim, not a shader fake** — that's the differentiator versus the dozens of "fluid art" apps already in the App Store, which are mostly stylized 2D shaders that look pretty but don't behave correctly when you tilt or change viscosity. Pour modeling actual Navier-Stokes advection means the experience teaches something real about how paint moves.

---

## 2. Refined Concept & Differentiation

**Core loop (one session, ~3–10 min):**
1. Pick a palette (preset or custom).
2. Tap-and-hold on canvas to pour a color from that point; release to stop.
3. Tilt the phone — paint flows toward gravity. Tilt harder, it flows faster.
4. Optionally swap to thinner/thickener "brushes" that locally modify viscosity, or to a "drop" tool that places density-mismatched droplets (this is what produces cells in real pour painting via silicone oil).
5. When happy, tap **Finish**. An interstitial ad plays. After ad: enter Preview mode.
6. Preview mode shows the canvas framed and on a wall. Swipe through frame styles and wall colors.
7. Save to Photos, set as wallpaper, or share. Optionally start a new pour.

**What makes this different from existing fluid-art apps:**
- **Real sim, real feedback.** Viscosity, density, and miscibility are actual sim parameters, not aesthetic toggles.
- **Tilt-as-gravity.** The accelerometer is the primary control, not a gimmick.
- **The framed/wall preview as a closing act.** Bridges the digital-to-physical confidence gap.

**What it is NOT:**
- Not a generic painting app (no brushes, no shapes).
- Not AR (v1). Wall preview is a 2D composite, not camera-based.
- Not a social/community app. No accounts, no gallery, no cloud (v1).

---

## 3. Target Audience

- **Wallpaper hunters** — want a one-of-a-kind, personal phone background.
- **Aspiring pour painters** — use it to experiment with color combos before committing to real materials.
- **Idle / satisfying-content seekers** — overlap with the ASMR, "oddly satisfying", and slime-video audiences.

Primary acquisition channel hypothesis: short-form video (TikTok/Reels/Shorts) of the tilt mechanic.

---

## 4. Feasibility Assessment

**Verdict: practical, but the fluid sim is the make-or-break component.** Build a sim prototype before committing to the rest of the spec.

**What's hard:**
- Real-time multi-color 2D fluid sim on phone (target: 256×576 grid, 60 fps, Metal compute).
- Tilt UX feel — accelerometer noise, dead zones, response curves need careful tuning.
- Color mixing semantics — use Oklab to avoid muddy RGB averaging.
- Cell formation (silicone-oil effect) — needs density field and surface tension term.

**What's easy:**
- SwiftUI shell, CoreMotion integration, frame/wall preview compositing, Photos export, AdMob integration.

**Prototype first (M0 spike):** Single-color Stable Fluids in Metal + CoreMotion gravity. If 60 fps on iPhone 13, proceed. If not, downgrade to hybrid sim and adjust marketing.

---

## 5. MVP Feature Set

**Canvas & sim core**
- Full-screen canvas, locked to phone aspect ratio.
- Eulerian fluid grid (256×576 target).
- Per-cell color (Oklab), velocity, density, viscosity.
- Gravity vector driven by `CMMotionManager`.
- Boundary conditions: sticky walls.

**Tools**
- **Pour** — tap-and-hold pours selected color at touch point.
- **Thinner** — local viscosity reduction.
- **Thickener** — local viscosity increase.
- **Drop** — places high-density-contrast droplet (cell creation tool).
- **Wipe** — clears a region back to substrate.
- **Reset canvas** — confirmation prompt.

**Palette**
- 6 preset palettes at launch (Ocean, Sunset, Earth, Neon, Mono, Pastel).
- Custom color picker (HSL wheel + recents).
- Active palette shows 5 color slots.

**Finish flow**
- **Finish** button triggers interstitial ad (AdMob). After ad: Preview mode.
- One ad surface only.

**Preview mode**
- Canvas in frame on wall composite.
- 5 frame styles, 5 wall colors.
- Pinch to zoom.
- Save to Photos, Share, Back to canvas (no second ad).

**Session management**
- No accounts. No cloud.
- Last 5 paintings cached locally.
- In-progress canvas auto-saved; restored on relaunch.

**Out of scope for v1:** AR wall preview, time-lapse export, IAP, iPad, Apple Pencil, community gallery.

---

## 6. UX Flows

**Cold start → first pour (target: under 20 seconds)**
```
App launch → splash (≤1.5s) → Home (last session thumbnail + "New Pour" + recents)
  → Tap "New Pour" → Palette picker overlay (skippable, defaults to Ocean)
  → Canvas + 2-second hint overlay → painting
```

**Painting → finish → preview**
```
Painting → Tap "Finish" → confirm dialog → interstitial ad
  → Preview mode (frame + wall) → Save/Share/Wallpaper
  → "Back to Canvas" (free, no ad) OR "Done" → home
```

**Critical UX rules:**
- Interstitial fires exactly once per finished painting.
- Tilt control always live during painting mode — no lock toggle.
- First 60 seconds of every session ad-free.

---

## 7. Technical Architecture

**Stack**
- **UI:** SwiftUI (iOS 17+)
- **Sim:** Metal compute shaders (custom kernels) + `MTKView`
- **Motion:** `CoreMotion` / `CMMotionManager` at 60 Hz
- **Photos:** `PhotosUI` + `PHPhotoLibrary`
- **Ads:** Google Mobile Ads SDK (AdMob), interstitial
- **Persistence:** Raw `Data` blobs for sim grids; PNG thumbnails + `UserDefaults` for recents

**Module structure**
```
Pour/
├── App/
│   ├── PourApp.swift
│   └── RootView.swift
├── Canvas/
│   ├── CanvasView.swift
│   ├── FluidSimulator.swift
│   ├── Renderer.swift
│   └── Shaders.metal
├── Motion/
│   └── MotionService.swift
├── Tools/
│   ├── ToolModel.swift
│   ├── ToolbarView.swift
│   └── PaletteView.swift
├── Preview/
│   ├── PreviewView.swift
│   ├── Frame.swift
│   └── Wall.swift
├── Finish/
│   ├── FinishFlow.swift
│   └── AdService.swift
├── Storage/
│   ├── CanvasStore.swift
│   └── RecentsStore.swift
└── Resources/
    ├── Frames/
    └── Walls/
```

**Threading model**
- Sim step runs on GPU each frame, dispatched from render loop.
- CPU per frame: read gravity, push to uniforms, handle touch, dispatch command buffer.
- All UI is `@MainActor`. Sim does not block UI.

**Save/restore**
- Sim grids at 256×576 ≈ 4.5 MB. Write to binary file on background thread.
- Restore on foreground if within 24h; otherwise discard.

---

## 8. Fluid Simulation (Deep Dive)

**Algorithm:** Jos Stam's Stable Fluids (Eulerian, semi-Lagrangian advection, Jacobi pressure solve).

**Grid fields per cell:**

| Field | Type | Purpose |
|---|---|---|
| `color` | `float4` (Oklab+A) | Pigment |
| `velocity` | `float2` | Flow vector |
| `density` | `float` | Buoyancy / cell formation |
| `viscosity` | `float` | Resistance to flow |

**Per-frame compute pipeline:**
1. Add forces (gravity × density)
2. Add sources (pour/drop touch injection)
3. Advect velocity (semi-Lagrangian backtrace)
4. Diffuse velocity (Jacobi, ~20 iterations)
5. Project (pressure Poisson solve, Jacobi, ~30–40 iterations)
6. Advect color & density
7. Surface tension (curvature-based, optional)
8. Render (color field → screen, slight gloss tone map)

**Color mixing:** Oklab throughout. Convert RGB → Oklab at injection, back to RGB at render.

**Cell formation:** Drop tool injects off-density region. Buoyancy drives rise/sink; surface tension keeps boundary coherent.

**Performance targets (iPhone 13 / A15):**
- 256×576 grid, 60 fps, thermals stable for 10 min.
- Fallback (A12/A13): 192×416 grid, 30 fps cap.

**References:**
- Jos Stam, "Stable Fluids" (1999) and "Real-Time Fluid Dynamics for Games" (2003)
- Mark Harris, GPU Gems Ch. 38
- Search: "metal fluid simulation" on GitHub

---

## 9. Monetization

- **Single ad surface:** AdMob interstitial on Finish.
- Trigger: user finishes a painting with at least one pour stroke.
- Frequency cap: 60s minimum between loads (AdMob built-in).
- ATT prompt: first time user reaches Finish step, not on launch.
- Return-to-canvas after preview is free.

---

## 10. Risks & Open Questions

**Technical**
- Battery/thermals: cap sim at 30 Hz on battery saver; suspend if idle 3s.
- Sim stability under aggressive tilt: velocity clamping + minimum diffusion floor.
- iPad/aspect ratios: v2 question.

**Product**
- "Rehearsal for real pour painting" — validate with beta testers from the hobby community.
- Wallpaper set flow: plan for "saved — now tap to set" hand-off, not one-tap promise.
- Ad model: single interstitial is a low load; rewarded layer is a v2 option.

**Open questions (resolve before build)**
1. "Set as Wallpaper" flow: worth complexity vs. just "Save to Photos"? Lean toward latter.
2. Canvas exactly screen aspect, or slightly larger? Lean exact for v1.
3. Color picker: HSL wheel + recents for v1.
4. Onboarding: 2-second hint overlay (full tutorial only if beta struggles).

---

## 11. Milestones

| # | Milestone | Scope | Est. wks |
|---|---|---|---|
| M0 | Sim spike | Single-color Stable Fluids, Metal, CoreMotion gravity, MTKView. Decision point. | 1–2 |
| M1 | Multi-color sim | Oklab, per-cell color & density, multi-pour source | 1 |
| M2 | Tool model & toolbar | Pour, Thinner, Thickener, Drop, Wipe | 1 |
| M3 | Palette & home screen | Preset palettes, custom picker, recents | 1 |
| M4 | Finish flow & preview | Frame/wall preview, save to Photos | 1 |
| M5 | Ad integration | AdMob interstitial, ATT prompt, frequency cap | 0.5 |
| M6 | Persistence & polish | Save/restore, onboarding hint, animations | 1 |
| M7 | TestFlight beta | ~10–20 testers, fix top issues | 2 |
| M8 | App Store submission | Screenshots, preview video, metadata, review | 0.5–1 |

Total: ~9–12 weeks part-time. M0 is the gating milestone.

---

## 12. Naming Notes

"Pour" is a placeholder. App Store already has at least one "Pour". Candidates:
- Tilt & Pour
- Marbled
- Decant
- Pigment
- Flow (probably taken)
- Resin (probably taken)

Run App Store search + USPTO TESS search before committing.
