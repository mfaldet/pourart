# Pour

A pour-painting simulator for iOS built on a real 2D fluid simulation, not a shader that looks like one.

You tip paint onto the canvas, tilt the phone to direct the flow under simulated gravity, play with viscosity and density the way you would with thinners and silicone oil, then preview the finished piece framed on a wall — as a wallpaper, or as a rehearsal before spending real money on resin and pigment.

**Why a real sim.** The existing "fluid art" apps are stylised 2D shaders: pretty, but they don't behave correctly when you tilt or change viscosity. Pour models actual advection (Eulerian stable fluids, multi-colour, Oklab mixing), so what you learn on the screen is true of paint.

**Status.** Pre-build. The fluid sim is the make-or-break component, so the first milestone is a Metal compute prototype (`PourSimSpike`) that proves 60 fps on a 256×576 grid on a phone before anything else gets built.

**Read in this order**

- [`SPEC.md`](SPEC.md) — product and engineering spec: concept, audience, feasibility, scope of v1
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — how the pieces fit: sim, motion input, rendering, preview, export
- [`DECISIONS.md`](DECISIONS.md) — the choices made along the way and why, newest first
- [`CHANGELOG.md`](CHANGELOG.md) — what changed
- [`CLAUDE.md`](CLAUDE.md) — working agreement for the AI pair-programming setup this project uses
- [`docs/`](docs/) — research and notes

**Stack.** Swift / SwiftUI · Metal compute · CoreMotion · iOS only

**License.** MIT — see [`LICENSE`](LICENSE).
