import SwiftUI
import simd

// ---------------------------------------------------------------------------
// PourTechnique — eight real acrylic pour painting techniques.
// ---------------------------------------------------------------------------
enum PourTechnique: String, CaseIterable, Identifiable {
    case dirtyPour, ringPour, dutchPour, flipCup, swipe, treeRing, stringPull, bloom
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dirtyPour:  return "Dirty Pour"
        case .ringPour:   return "Ring Pour"
        case .dutchPour:  return "Dutch Pour"
        case .flipCup:    return "Flip Cup"
        case .swipe:      return "Swipe"
        case .treeRing:   return "Tree Ring"
        case .stringPull: return "String Pull"
        case .bloom:      return "Bloom"
        }
    }

    var description: String {
        switch self {
        case .dirtyPour:
            return "Layer colors in a cup then pour in a continuous stream. Colors merge as they spread, creating organic marbled ribbons."
        case .ringPour:
            return "Pour colors one at a time in the same spot, then tilt to expand the concentric rings outward into flowing bands."
        case .dutchPour:
            return "Pour paint then blow with a hair dryer or straw. Creates feathered, lace-like cells at every boundary."
        case .flipCup:
            return "Layer colors in a cup, place canvas face-down on top, then flip. Lift the cup slowly to reveal a blooming spread."
        case .swipe:
            return "Pour base stripes then drag a palette knife or card across the surface. Reveals hidden layers with dramatic streaks."
        case .treeRing:
            return "Pour colors from height in the center repeatedly, tilting to create concentric ovals like tree growth rings."
        case .stringPull:
            return "Dip a string in paint, lay it on the canvas, then pull while pressing down. Creates feathery, organic shapes."
        case .bloom:
            return "Drop paint onto a wet base and watch it bloom outward. Silicone oil creates striking cellular lacing as density contrasts drive separation."
        }
    }

    var icon: String {
        switch self {
        case .dirtyPour:  return "arrow.down.circle.fill"
        case .ringPour:   return "circle.circle.fill"
        case .dutchPour:  return "wind"
        case .flipCup:    return "arrow.up.and.down.circle"
        case .swipe:      return "hand.draw.fill"
        case .treeRing:   return "target"
        case .stringPull: return "line.diagonal"
        case .bloom:      return "burst.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .dirtyPour:  return [.blue, .purple, .red]
        case .ringPour:   return [.teal, .cyan, .white]
        case .dutchPour:  return [.orange, .yellow, .white]
        case .flipCup:    return [.purple, .blue, .teal]
        case .swipe:      return [.red, .orange, .yellow]
        case .treeRing:   return [.green, .teal, .blue]
        case .stringPull: return [.pink, .purple, .blue]
        case .bloom:      return [.white, .cyan, .blue]
        }
    }

    var consistencyTip: String {
        switch self {
        case .dirtyPour:  return "Medium — like warm honey. All colors should flow at the same rate."
        case .ringPour:   return "Slightly thin — paint needs to spread easily when the canvas tilts."
        case .dutchPour:  return "Very thin — paint must move with air. Add 30–40% pouring medium."
        case .flipCup:    return "Medium-thin — thick enough to layer without mixing in the cup."
        case .swipe:      return "Medium — the swipe color should be slightly thicker than the base layers."
        case .treeRing:   return "Thin — needs to spread with minimal tilt pressure."
        case .stringPull: return "Thick — needs to cling to the string without immediate dripping."
        case .bloom:      return "Thin base + medium drops. Density contrast drives the bloom."
        }
    }

    var colorsTip: String {
        switch self {
        case .dirtyPour:  return "3–6 colors. High contrast works best — try complementary pairs."
        case .ringPour:   return "4–5 colors. Analogous palettes create beautiful gradient rings."
        case .dutchPour:  return "3–4 bold colors. Blowing mixes edges, so high contrast reads best."
        case .flipCup:    return "4–5 colors. Dark + light contrast reveals the pattern clearly."
        case .swipe:      return "2–3 base colors + 1 strong swipe color. The swipe dominates."
        case .treeRing:   return "3–5 colors. Warm + cool contrast creates depth in each ring."
        case .stringPull: return "2–3 base colors + 1–2 opaque string colors."
        case .bloom:      return "Light base + 2–3 darker drops. White or gold enhances cell lacing."
        }
    }
}

// ---------------------------------------------------------------------------
// CanvasShape — artist's intended canvas orientation.
// ---------------------------------------------------------------------------
enum CanvasShape: String, CaseIterable, Identifiable {
    case portrait, landscape, square, round
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .portrait:  return "Portrait"
        case .landscape: return "Landscape"
        case .square:    return "Square"
        case .round:     return "Round"
        }
    }

    var icon: String {
        switch self {
        case .portrait:  return "rectangle.portrait"
        case .landscape: return "rectangle"
        case .square:    return "square"
        case .round:     return "circle"
        }
    }
}

// ---------------------------------------------------------------------------
// ColorHarmony — generates 5-color palettes from a base hue.
// ---------------------------------------------------------------------------
enum ColorHarmony: String, CaseIterable, Identifiable {
    case analogous, complementary, splitComplementary, triadic, tetradic, monochromatic
    var id: String { rawValue }

    var label: String {
        switch self {
        case .analogous:           return "Analogous"
        case .complementary:       return "Complementary"
        case .splitComplementary:  return "Split-Comp"
        case .triadic:             return "Triadic"
        case .tetradic:            return "Tetradic"
        case .monochromatic:       return "Mono"
        }
    }

    var description: String {
        switch self {
        case .analogous:           return "Neighbors on the wheel — peaceful and harmonious"
        case .complementary:       return "Opposite hues — maximum contrast and vibrance"
        case .splitComplementary:  return "Base + two neighbors of its complement — dynamic but balanced"
        case .triadic:             return "Three evenly spaced hues — bold and colorful"
        case .tetradic:            return "Four hues forming a rectangle — complex and rich"
        case .monochromatic:       return "One hue, varying value — elegant and unified"
        }
    }

    var scienceTip: String {
        switch self {
        case .analogous:
            return "Analogous palettes flow naturally — great for landscapes and soft pours. Colors stay in the same temperature family, staying cohesive even when they mix."
        case .complementary:
            return "Complementary colors create maximum contrast. They'll vibrate at cell boundaries in a pour. Use a 70/30 ratio — one dominant color, one accent — to avoid visual chaos."
        case .splitComplementary:
            return "A gentler alternative to full complementary. The two split colors add richness without harsh contrast. Great for balanced pours that still have energy."
        case .triadic:
            return "Triadic palettes are bold and lively. Keep saturation slightly lower on two of the three colors so one can lead — otherwise all three compete equally."
        case .tetradic:
            return "Four simultaneous color relationships — complex and rich. Works best when two of the four colors are muted. Unpredictable and exciting cell formations."
        case .monochromatic:
            return "Single-hue palettes feel refined and intentional. Value contrast (light vs. dark) does all the work. Add one near-white for cell highlight separation."
        }
    }

    func palette(hue h: Double, saturation s: Double, brightness b: Double) -> [Color] {
        func c(_ hue: Double, sat: Double? = nil, bri: Double? = nil) -> Color {
            Color(hue: (hue + 10).truncatingRemainder(dividingBy: 1),
                  saturation: min(max(sat ?? s, 0), 1),
                  brightness: min(max(bri ?? b, 0.1), 1))
        }
        switch self {
        case .analogous:
            return [c(h-0.10), c(h-0.05), c(h), c(h+0.05), c(h+0.10)]
        case .complementary:
            return [c(h), c(h, sat: s*0.65, bri: min(b*1.1,1)),
                    c(h+0.5), c(h+0.5, sat: s*0.65),
                    c(h, sat: s*0.35, bri: min(b*1.25,1))]
        case .splitComplementary:
            return [c(h), c(h, sat: s*0.6, bri: min(b*1.1,1)),
                    c(h+0.417), c(h+0.583),
                    c(h, sat: s*0.3, bri: min(b*1.3,1))]
        case .triadic:
            return [c(h), c(h, sat: s*0.7),
                    c(h+1.0/3), c(h+1.0/3, sat: s*0.7),
                    c(h+2.0/3)]
        case .tetradic:
            return [c(h), c(h+0.25), c(h+0.5), c(h+0.75),
                    c(h, sat: s*0.45, bri: min(b*1.15,1))]
        case .monochromatic:
            return (0..<5).map { i in
                let t = Double(i) / 4.0
                return c(h, sat: 0.15 + s * t, bri: b * (1.0 - 0.35 * t) + 0.2 * (1.0 - t))
            }
        }
    }

    // RGB extraction helper used in PaletteBuilderView
    func paletteRGB(hue: Double, saturation: Double, brightness: Double) -> [SIMD3<Float>] {
        palette(hue: hue, saturation: saturation, brightness: brightness).map { color in
            var r: CGFloat = 0, g: CGFloat = 0, bv: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &bv, alpha: nil)
            return SIMD3(Float(r), Float(g), Float(bv))
        }
    }
}
