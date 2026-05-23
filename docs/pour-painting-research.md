# Pour Painting Research
_Compiled 2026-05-23 — pre-M1 reference. All sim tuning decisions should trace back to this document._

---

## 1. What Pour Painting Actually Is

Acrylic pour painting (also called fluid art) is a form of abstract painting where heavily thinned, flow-conditioned acrylic paint is poured, flipped, swiped, or blown onto a canvas. The artist does not use brushes. Control comes from:

- **Where** paint is deposited
- **Tilt angle and direction** of the canvas
- **Sequence** of color layering
- **Additives** (silicone oil, alcohol) that change how colors interact
- **Tools** (spatulas, hairdryers, chains, strings) that physically move wet paint

The work is never fully in the artist's control — unpredictability is part of the appeal and the skill. A good pour painter guides probabilities, not outcomes.

---

## 2. The Physical Nature of Pour Paint (Critical for Sim)

This is the most important section for the app. The current M0 sim behaves like water or gas. Real pour paint is fundamentally different.

### 2a. Consistency — "Warm Honey"

The universal reference point across all pour painting communities is **warm honey**. Specifically:

- Thick enough to cling to a stir stick and drip off in a slow ribbon
- When that ribbon falls back into the cup, it forms a **small mound that takes 2–3 seconds to absorb back** into the surface
- Comparable to: warm honey, motor oil, chocolate syrup, pancake batter

**Viscosity implication for sim:**
- Velocity dissipates slowly — paint that starts moving keeps moving for a while
- Paint does NOT splash. It flows in ribbons and sheets.
- Surface tension keeps edges coherent — paint doesn't atomize into droplets
- Paint does NOT mix fully on contact — colors sit next to each other, creating distinct veins and zones before slowly blending at boundaries
- **Gravity effect is slow and majestic, not immediate.** A tilted canvas takes several seconds before flow becomes visible.

### 2b. How Gravity Drives Flow

Canvas tilting is the primary method of spreading paint. Key behaviors:
- Tilt 15° and paint begins a slow, deliberate flow toward the low edge
- Faster tilt = more chaotic, faster flow — but even "fast" is slow by water standards
- Paint flows to canvas edges and **drips off** — real pour painters put the canvas on cups to elevate it and catch drips
- Rotating the canvas while tilting creates circular flow and preserves cell roundness
- Artists deliberately pause after each tilt to **let gravity settle** before tilting again
- Tilting too fast causes paint to rush and lose detail; too slow and nothing happens

**The phone-as-canvas metaphor:** tilting the phone should feel like tilting a physical tray of honey. There is perceptible lag and momentum. The paint does not respond instantly to small tilts.

### 2c. Drying / Workability Window

- Pour paint stays workable for **15–30 minutes** on canvas before it starts to skin over
- After that, tilting creates tearing and cracking rather than flow
- For the app: paint is always wet (infinite workability is fine for v1, unlike real pour painting where you race the clock)

---

## 3. Techniques (Exhaustive)

These are the core techniques used by pour painters, ordered from simplest to most complex. The app's tools should enable the most common ones.

### 3a. Canvas Tilt (Universal)
Used in virtually every technique. After depositing paint by any method, the artist tilts and rotates the canvas to spread paint.
- **Direction:** low edge receives paint; artist rotates to redistribute
- **Speed:** slow and deliberate; pause between direction changes
- **App analog:** accelerometer gravity → flow direction. This IS our primary control.

### 3b. Traditional / Clean Pour
Pour each color separately in distinct zones on the canvas. Colors touch but don't pre-mix.
- Result: clean, distinct color regions that blend only at boundaries
- App analog: user pours one color at a time from specific tap points

### 3c. Dirty Pour
Layer all colors into one cup in sequence, then pour the entire cup at once.
- Colors stay in layers — the pouring action and gravity reveal the layering as interlocking ribbons and cells
- Result: rich color complexity, good cell potential
- App analog: the "pour" tool with multiple colors already loaded could approximate this

### 3d. Flip Cup
A dirty pour inverted. Canvas placed face-down on the loaded cup, assembly flipped, cup lifted.
- The gravity-reversal moment is what makes this technique distinctive — paint rushes down all at once when the cup is lifted
- Creates dramatic circular blobs of color with cells radiating outward
- App analog: not directly mappable to phone UX without a specific interaction (future consideration)

### 3e. Swipe
Paint is laid on canvas in strips or puddles, then a flat tool (spatula, card, damp paper towel) is dragged across the surface in one motion.
- The swiping action displaces the top layer of paint, revealing layers beneath and creating streaks and lacing
- Cells appear along the swipe line where layers interact
- **This is the strongest cell-creation technique** — much more reliable than flip cup
- App analog: a "swipe" tool where finger drag pulls paint across existing layers

### 3f. Dutch Pour
A base color is poured over other colors, then a hairdryer on low setting blows the base color outward, revealing the colors underneath in "petals."
- Result: flower-like, feathered, lacy patterns with fine detail
- The airflow creates very thin paint films at the leading edge (lacing)
- App analog: could be a "blow" tool that creates a directional force vector — v2 consideration

### 3g. Tree Ring Pour
A dirty pour cup is poured in a tight circular motion at one spot, building up concentric rings. Canvas is then tilted in circular motion to stretch the rings outward.
- The rings remain distinct because each pour ring is a separate density layer
- Result: concentric circles, like a tree cross-section or topographic map
- App analog: the pour tool used with tight circular drag motion

### 3h. String Pull
A string coated in paint is dragged across the canvas through a base coat.
- Creates organic veining, feather shapes, or flower patterns depending on how the string is handled
- Multiple strings can be pulled in sequence
- App analog: a "drag" tool that creates a thin, pulled streak — v2 consideration

### 3i. Balloon Smash
A semi-inflated balloon is smashed into paint puddles.
- Creates quasi-circular cell patterns from the compression
- Not directly relevant to app v1

### 3j. Funnel Pour / Open-cup Pour
Paint is poured through a funnel or cylinder, which concentrates the flow and creates spiraling column patterns.
- Not directly relevant to app v1 — more of a physical tool thing

---

## 4. Cell Formation — The Signature Look of Pour Painting

Cells are the closed, bubble-like regions that make pour paintings unmistakably recognizable. Understanding cells is critical because they're the visual payoff of the Drop tool.

### 4a. The Physics (Rayleigh-Taylor Instability)

Cells form through **Rayleigh-Taylor instability**: when fluids of different densities are stacked with a denser fluid on top, the configuration is unstable. The denser paint sinks; the lighter paint rises. As they trade places, they collect paint particles at their boundaries and form visible closed regions.

Key facts:
- **Dense pigments** (titanium white, heavy-metal colors like cobalt blue, cadmium red) sink through lighter layers
- **Light pigments** (hansa yellow, magenta, carbon black) rise
- The cells form at the interface — you see them as the light paint rises through the dark, or vice versa
- Heat (from a torch) accelerates this by reducing surface tension and allowing the instability to develop faster

### 4b. Silicone Oil's Role

Silicone oil does NOT mix with water-based acrylic paint. When added to a paint color, it creates tiny oil droplets suspended in the paint. As those droplets rise through adjacent paint layers (oil is lighter than acrylic binder), they push paint aside and create cells.

- 1–3 drops per 2–3 oz of paint is enough
- Added to only some colors (usually the one you want to see cells in), not all
- More silicone = more cells, but also more risk of paint adhesion failure
- **High-viscosity silicone oil → large, defined cells**
- **Low-viscosity silicone oil → small, spreading cells**
- Stirring vigorously before pouring → smaller, more numerous cells
- Minimal stirring → larger, fewer cells

### 4c. Heat / Torch

A propane torch or heat gun swept quickly over the wet canvas:
- Breaks surface tension locally, allowing underlying layers to rise through
- Quick, high pass from above → small cells
- Slow, close pass → large cells
- Over-torching destroys cells and muddles colors

### 4d. Cell-formation Methods Ranked by Reliability

1. **Silicone oil + swipe** — most reliable, large well-defined cells
2. **Silicone oil + flip cup** — reliable, circular cells
3. **Density mismatch alone** (titanium white under other colors) — moderate, unpredictable
4. **Alcohol drops** — small cells, evaporate-driven
5. **Heat alone** — inconsistent without silicone

### 4e. Preventing Cells

For artists who want smooth, cell-free pours:
- Avoid silicone
- Keep all paint colors at similar density
- Use GAC 800 or Glue-All as pouring medium (both resist cell formation)
- Keep paint thicker (closer to body paint consistency)

---

## 5. Color Behavior in Pour Painting

### 5a. Layering and Veining

Colors in a dirty pour cup stay in rough layers. When poured and tilted:
- Layers intermix at edges, creating thin veins of transitional color
- Layers remain distinct in thick zones (the paint's viscosity resists full mixing)
- Lighter colors tend to bloom up through darker ones

### 5b. Mixing — The Muddy Brown Problem

**This is critical for the app.** In real pour painting:
- Red + green = brown/gray mud (subtractive mixing)
- Pour painters avoid muddying by not over-tilting, not over-mixing
- The "beautiful" look comes from colors being *adjacent and transitioning*, not fully mixed
- The artist's goal is to keep colors distinct while allowing controlled boundary blending

**Sim implication:** Oklab color space blending is correct. BUT the sim also needs to resist full mixing — paint that has been sitting still for 0.5 seconds should resist further diffusion. We need a very low diffusion rate for color (separate from velocity diffusion).

### 5c. Pigment Density Differences

Real pigment densities (lighter = rises, heavier = sinks):
- Heavy: titanium white, cobalt blue, cadmium colors, iron oxides (earth tones)
- Medium: most synthetic organics
- Light: carbon black (despite looking heavy), hansa yellow, quinacridone magenta

This is counterintuitive — **black rises, white sinks.** That's why titanium white under black often produces cells: the white is unstable beneath the black.

---

## 6. Tools and Materials Summary

| Tool/Material | Purpose | App Analog |
|---|---|---|
| Pouring medium (Floetrol, GAC800) | Thins paint to honey consistency without losing color; prevents cracking | Built into base viscosity of sim |
| Silicone oil (1–5 drops/color) | Creates cells via density mismatch | Drop tool |
| Isopropyl alcohol | Smaller cells, fast-evaporating | Could be a modifier in v2 |
| Propane torch / heat gun | Opens cells, breaks surface tension | Could be a "heat" tool in v2 |
| Spatula / card / paper towel | Swipe technique | Swipe tool |
| Hairdryer | Dutch pour air movement | Blow tool in v2 |
| Canvas on raised cups | Allows paint to drip off edges, levels surface | Implied by app canvas |
| String / chain | String-pull technique | v2 |

---

## 7. Common Mistakes (What Looks Wrong and Why)

| Mistake | Visual Result | Root Cause |
|---|---|---|
| Paint too thin | Watery, no definition, cells don't hold | Too much water / medium |
| Paint too thick | Doesn't flow, brush-texture visible, stiff | Not enough medium |
| Over-tilting | Colors fully mud, detail lost | Too much movement before paint settles |
| Too much silicone | Paint fish-eyes, adhesion failure, cells too big and pop | Silicone overdose |
| Torching too long | Cells appear then vanish, muddy surface | Over-heating destroys cell structure |
| Colors all same density | No cells form naturally | Need at least one outlier density color |
| Wrong pour order | Unexpected color dominance | Denser colors poured last end up on top |

---

## 8. Sim Tuning Implications for M1

Based on this research, here is what the M0 sim needs changed to feel like real pour paint:

### Critical (must fix before M1 ships)

1. **Dramatically increase viscosity.** Paint should feel like honey, not water. In sim terms:
   - Much higher diffusion coefficient (more Jacobi iterations or higher alpha)
   - Velocity damping: kill ~40% of velocity each frame (paint resists motion)
   - Gravity scale needs to be 5–10x lower than current — paint moves slowly

2. **Decouple color diffusion from velocity diffusion.** Color should barely diffuse on its own. Once deposited, colors should mostly stay put and only move via advection. This preserves the distinct veining look.

3. **Surface tension term is not optional — it's essential.** Without it, colors bleed into each other at boundaries. The curvature-based force in Shaders.metal (step 7, currently "optional") must be implemented before M1.

4. **Density field drives cell formation, not silicone.** The Drop tool should inject a region with density offset of ±20–30% relative to surroundings. Buoyancy force in addForces must be strong enough to actually move this — currently density barely affects behavior.

5. **Tilt response must feel slow and deliberate.** The gravity scale in MotionService (currently `gravityScale = 15.0`) should probably be 2–4. With viscous paint, small tilts should produce slow drift, not fast flow.

### Important (affects quality significantly)

6. **Add velocity drag / friction.** Paint that's moving should decelerate unless actively pushed by gravity. Right now velocity persists indefinitely (inviscid behavior). Add a `vel *= 0.92` (or similar) damping pass each frame.

7. **Boundary behavior: paint piles at edges.** In real pour painting, paint hits the canvas edge and drips off. For the app, paint should pile at edges and "drip" if density is high enough — or simply stop (sticky walls, current behavior). Sticky walls are fine for v1 but the density should accumulate at walls.

8. **Color blending at boundaries only.** Colors should blend in a narrow band at their interface, not globally. This requires color diffusion to be spatially aware of color gradients — essentially only diffuse where two different colors meet.

### For the Drop tool specifically

The cell-creation mechanic (Drop tool) needs:
- A density injection that is ±20–30% off from the local paint density
- Buoyancy force strong enough to actually drive the droplet up or down through surrounding paint
- Surface tension to keep the droplet's edge coherent as it travels
- The droplet should be small (8–15 cells radius), dense color with full opacity

Without these three working together, cells will not appear. This is the highest-risk feature of the app.
