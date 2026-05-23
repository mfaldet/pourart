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

**Next:** Surface tension kernel (currently `surfaceTension` uniform is plumbed but unused). After that: multi-touch pour, then move on to M2 (tool model — Thinner, Thickener, Drop, Wipe).
