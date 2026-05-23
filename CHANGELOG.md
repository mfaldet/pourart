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
