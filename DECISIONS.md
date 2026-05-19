# Decisions

Trade-off calls, locked choices, and deferred questions. Each entry: decision · rationale · date.

---

## Architecture

**Eulerian grid (Stable Fluids), not particle-based**
Jos Stam's semi-Lagrangian advection is unconditionally stable and GPU-parallelizable at our grid size. Particle systems require per-particle state that doesn't vectorize as cleanly on Metal compute.
_2026-05-18 (spec)_

**Custom Metal compute kernels, not Metal Performance Shaders**
MPS doesn't expose the per-cell viscosity and density fields the sim needs. Custom kernels give full control over multi-color advection.
_2026-05-18 (spec)_

**iOS 17+ minimum target**
Gets `Observation` framework, modern CoreMotion APIs, and a clean Metal-in-SwiftUI story. Cuts ~8% of active iPhones (A11 and below) but those can't hit the perf target anyway.
_2026-05-18 (spec)_

---

## Color

**Oklab color space for grid storage and blending**
RGB averaging produces muddy browns (red + green). Oklab is perceptually uniform — mixed colors look like mixed pigments. Cost: two small conversion kernels per frame.
_2026-05-18 (spec)_

---

## Monetization

**Single interstitial on Finish, nowhere else**
One ad surface keeps the placement honest and preserves the creative flow. Adding ads to other surfaces is explicitly out of scope for v1. Revisit rewarded-ad layer in v2 only if LTV analysis demands it.
_2026-05-18 (spec)_

**ATT prompt on first Finish, not on launch**
Better consent rate. Less aggressive cold-start experience.
_2026-05-18 (spec)_

---

## Scope (Locked Out of v1)

**No accounts, no cloud** — scope death. Locked out.
**iPhone only** — iPad aspect ratio diverges from wallpaper output. v2 conversation.
**No AR wall preview** — 2D composite is enough for v1. v2 feature.
**No time-lapse export** — interesting but not core. v2.

---

## Open (Resolve Before M4)

- "Set as Wallpaper" flow: direct deep-link to Shortcuts, or just "Save to Photos"? Lean toward save-only for v1 simplicity.
- Canvas aspect: exactly screen size, or slightly larger with crop-at-save? Lean exact.

---

## M0 Gate Result

_To be filled after spike runs on device._

| Metric | Target | Actual |
|---|---|---|
| FPS (iPhone 13) | 60 | — |
| Grid size | 256×576 | — |
| Thermal stability (10 min) | No throttle | — |
| Verdict | Proceed / Fallback | — |
