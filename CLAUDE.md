# Pour — Agent Guide

iOS pour-painting simulator. SwiftUI + Metal compute shaders. See SPEC.md for full product and engineering spec.

---

## Session Start

1. Read `DECISIONS.md` — locked choices and open questions
2. Read `CHANGELOG.md` — current milestone and recent changes
3. Check current milestone against SPEC.md §11 and confirm scope before writing any code

---

## Key Files

| File | Purpose |
|---|---|
| `SPEC.md` | Full product + engineering spec (source of truth) |
| `DECISIONS.md` | Trade-off log — read before making architectural choices |
| `CHANGELOG.md` | Append an entry for every meaningful change |
| `PourSimSpike/` | M0 throwaway spike — proven shader code will be ported, not this project |
| `Pour/` | Production app (created after M0 passes perf gate) |

---

## Rules

1. **M0 first.** Do not write SwiftUI shell, ad code, or preview compositing until the sim spike passes its performance gate (60 fps on A14+, no thermal throttle in 10 min). The gate result goes in DECISIONS.md.
2. **One ad surface.** Interstitial on Finish only. Do not add ad calls anywhere else.
3. **No accounts, no cloud.** Locked out of v1.
4. **iPhone only.** iPad is a v2 conversation.
5. **Append CHANGELOG.md** after every meaningful commit.
6. **Log trade-offs in DECISIONS.md**, not in comments or PR descriptions.
7. Keep the debug overlay (velocity field, pressure field, density field) toggleable — it's free to maintain and essential for sim diagnosis.

---

## Sim Architecture (M0 spike)

Algorithm: Jos Stam Stable Fluids — Eulerian, semi-Lagrangian advection, Jacobi pressure solve.

Per-frame Metal compute pipeline:
1. Add forces (gravity × density)
2. Add sources (touch injection)
3. Advect velocity
4. Diffuse velocity (Jacobi, ~20 iter)
5. Project / pressure solve (Jacobi, ~30–40 iter)
6. Advect color & density
7. Surface tension (optional, single pass)
8. Render to screen

Grid target: 256×576 cells. Fallback for A12/A13: 192×416, 30 fps cap.
Color space: Oklab in grid, convert RGB↔Oklab at injection/render.

---

## Current Milestone: M0 — Sim Spike

Goal: single-color Stable Fluids running in Metal on a bare MTKView, gravity from CoreMotion, debug overlay toggleable with a tap. Throwaway project — code quality matters less than proving the perf budget.

Perf gate: 60 fps on iPhone 13, no thermal throttle in 10 minutes.
