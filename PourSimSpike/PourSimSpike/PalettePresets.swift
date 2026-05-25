import SwiftUI
import simd

// ---------------------------------------------------------------------------
// PalettePresets.swift — the full curated library, organized by category.
// ---------------------------------------------------------------------------

private func hex(_ value: UInt32) -> SIMD3<Float> {
    SIMD3(
        Float((value >> 16) & 0xFF) / 255,
        Float((value >>  8) & 0xFF) / 255,
        Float( value        & 0xFF) / 255
    )
}

private func c(_ name: String, _ hexValue: UInt32) -> PaletteColor {
    PaletteColor(name: name, rgb: hex(hexValue))
}

private func P(_ name: String, _ icon: String, _ cat: PaletteCategory,
               _ colors: [PaletteColor]) -> Palette {
    Palette(name: name, icon: icon, category: cat, colors: colors)
}

// ---------------------------------------------------------------------------
// Library — every built-in palette, sorted into categories.
// ---------------------------------------------------------------------------
extension Palette {

    static let library: [Palette] = [

        // ── Classic ────────────────────────────────────────────────────
        .ocean, .sunset, .earth, .neon, .mono, .pastel,

        P("Galaxy", "sparkles", .classic, [
            c("Void",    0x0B0B2A), c("Nebula",  0x2A1F5C),
            c("Aurora",  0x6E3A8E), c("Magenta", 0xC95FBE),
            c("Mist",    0xFFE5F1)]),

        P("Aurora", "sparkles.tv.fill", .classic, [
            c("Lime",   0x00FF87), c("Cyan",   0x60EFFF),
            c("Cobalt", 0x0061FF), c("Plum",   0xBD00FF),
            c("Pink",   0xFE00FE)]),

        P("Marble", "circle.hexagongrid.fill", .classic, [
            c("Cream", 0xF4F1ED), c("Sand", 0xBFB3A6),
            c("Stone", 0x7A7165), c("Onyx", 0x2D2A26),
            c("Gold",  0xC9A86A)]),

        P("Lava", "flame.fill", .classic, [
            c("Char",  0x1A0F00), c("Coal",  0x6B0F00),
            c("Ember", 0xC42E00), c("Flame", 0xFF6B00),
            c("Spark", 0xFFD700)]),

        P("Pearl", "circle.dashed", .classic, [
            c("Snow",    0xF8F5F2), c("Ivory",  0xE8DDD0),
            c("Buff",    0xC9B7A4), c("Tawny",  0x8E7C70),
            c("Champ.",  0xFFE5B4)]),

        // ── Nature ─────────────────────────────────────────────────────
        P("Forest", "tree.fill", .nature, [
            c("Pine",   0x1A2E1A), c("Moss",   0x3E5C2C),
            c("Sage",   0x6B8E47), c("Lichen", 0xB5C97D),
            c("Wheat",  0xF0EAC2)]),

        P("Coral Reef", "fish.fill", .nature, [
            c("Coral", 0xFF6B9D), c("Peach",  0xFFA07A),
            c("Sun",   0xFFDB58), c("Lagoon", 0x4ECDC4),
            c("Sea",   0x95E1D3)]),

        P("Cherry Blossom", "leaf.circle.fill", .nature, [
            c("Snow",   0xFFEEF2), c("Petal",  0xFFB7C5),
            c("Sakura", 0xFF89A5), c("Plum",   0xC4577F),
            c("Bark",   0x6B2737)]),

        P("Autumn", "leaf.fill", .nature, [
            c("Bark",   0x4A2C1A), c("Burgundy", 0x8B2500),
            c("Pumpkin",0xC25A00), c("Honey",    0xE8A24C),
            c("Wheat",  0xD4A574)]),

        P("Lavender Field", "leaf", .nature, [
            c("Mist",    0xEAE4F0), c("Lilac",   0xB19CD9),
            c("Purple",  0x9370DB), c("Royal",   0x6A5ACD),
            c("Indigo",  0x4B0082)]),

        P("Stormy Sky", "cloud.bolt.fill", .nature, [
            c("Slate",   0x2D3548), c("Pewter",  0x4B5267),
            c("Silver",  0x708090), c("Mist",    0xB0C4DE),
            c("Cloud",   0xE6E8EE)]),

        P("Desert", "sun.max.fill", .nature, [
            c("Sienna", 0x8B4513), c("Bronze", 0xCD853F),
            c("Sand",   0xF4A460), c("Linen",  0xDEB887),
            c("Khaki",  0xC19A6B)]),

        P("Tropical", "palmtree.fill", .nature, [
            c("Jungle",   0x2E8B57), c("Lime",   0x98FB98),
            c("Wheat",    0xF5DEB3), c("Orchid", 0xDDA0DD),
            c("Hibiscus", 0xFF6F91)]),

        // ── Mood ───────────────────────────────────────────────────────
        P("Calm", "circle", .mood, [
            c("Mist",  0xB8DCE0), c("Sage",  0xA1C5C8),
            c("Olive", 0x8AA9A0), c("Pine",  0x738D78),
            c("Moss",  0x5C7050)]),

        P("Energetic", "bolt.fill", .mood, [
            c("Red",     0xFF0033), c("Tangerine", 0xFF8C00),
            c("Gold",    0xFFD700), c("Lime",      0xADFF2F),
            c("Cyan",    0x00CED1)]),

        P("Romantic", "heart.fill", .mood, [
            c("Blush",   0xFFB6C1), c("Pink",   0xFF69B4),
            c("Crimson", 0xDC143C), c("Wine",   0x8B0000),
            c("Cocoa",   0x4B0011)]),

        P("Mysterious", "moon.stars.fill", .mood, [
            c("Void",  0x1F0A2C), c("Aubergine", 0x4A1F5C),
            c("Plum",  0x7B3F8C), c("Orchid",    0xB070A0),
            c("Rose",  0xDC9FB4)]),

        P("Joyful", "sun.and.horizon.fill", .mood, [
            c("Sun",     0xFFD93D), c("Cherry", 0xFF6B6B),
            c("Mint",    0x4ECDC4), c("Peach",  0xFFA07A),
            c("Hibiscus",0xFF6B9D)]),

        P("Dramatic", "theatermasks.fill", .mood, [
            c("Black",   0x000000), c("Crimson", 0xB91C1C),
            c("Gold",    0xFBBF24), c("White",   0xFFFFFF),
            c("Steel",   0x4B5563)]),

        // ── Artist-Inspired ────────────────────────────────────────────
        P("Monet's Garden", "paintbrush.fill", .artist, [
            c("Pond",   0x84A98C), c("Linen",  0xBFDFC0),
            c("Lily",   0xFFE5B4), c("Peach",  0xFFB088),
            c("Willow", 0x6B8E83)]),

        P("Van Gogh", "moon.fill", .artist, [
            c("Night",   0x0A0E27), c("Indigo", 0x1E3A5F),
            c("Cobalt",  0x3D6FB8), c("Sun",    0xF5C942),
            c("Cream",   0xFFE69C)]),

        P("Klimt Gold", "circle.grid.cross.fill", .artist, [
            c("Ink",    0x1F1A14), c("Bronze",  0xC49A3F),
            c("Gold",   0xBE9117), c("Wheat",   0xDAB849),
            c("Honey",  0xF5D061)]),

        P("Picasso Blue", "square.fill.on.square.fill", .artist, [
            c("Midnight", 0x1E3A5F), c("Cobalt",  0x3D6FB8),
            c("Sky",      0x6B96C9), c("Mist",    0xB5C8DD),
            c("Bone",     0xE8E8E8)]),

        P("Rothko", "rectangle.split.3x1.fill", .artist, [
            c("Rust",   0xC2410C), c("Crimson", 0xDC2626),
            c("Amber",  0xFBBF24), c("Slate",   0x4B5563),
            c("Coal",   0x1F2937)]),

        P("Frida", "leaf.arrow.triangle.circlepath", .artist, [
            c("Magenta", 0xC2185B), c("Tangerine", 0xFF6F00),
            c("Sun",     0xFDD835), c("Jade",      0x2E7D32),
            c("Ocean",   0x1565C0)]),

        // ── Era ────────────────────────────────────────────────────────
        P("70s Earth", "tortoise.fill", .era, [
            c("Cocoa", 0x6B4423), c("Sienna", 0x8B4513),
            c("Rust",  0xCD853F), c("Mustard",0xD2691E),
            c("Gold",  0xDAA520)]),

        P("80s Synthwave", "music.note", .era, [
            c("Magenta", 0xFF006E), c("Plum",   0x8338EC),
            c("Cobalt",  0x3A86FF), c("Orange", 0xFB5607),
            c("Gold",    0xFFBE0B)]),

        P("90s Pastel", "scribble.variable", .era, [
            c("Bubble",  0xFF99CC), c("Mint",   0x99FFCC),
            c("Apricot", 0xFFCC99), c("Lilac",  0xCC99FF),
            c("Butter",  0xFFFFCC)]),

        P("Y2K", "diamond.fill", .era, [
            c("Magenta",  0xFF00FF), c("Cyan",  0x00FFFF),
            c("Hot Pink", 0xFF1493), c("Chrome",0xC0C0C0),
            c("Yellow",   0xFFFF00)]),

        P("Cyberpunk", "cpu.fill", .era, [
            c("Crimson", 0xFF003C), c("Tangerine", 0xFF8C00),
            c("Cyan",    0x00FFFF), c("Violet",    0xB300FF),
            c("Night",   0x0A0E27)]),

        // ── Cultural ───────────────────────────────────────────────────
        P("Japanese Spring", "leaf.circle", .cultural, [
            c("Sakura", 0xF8C3CD), c("Plum",  0xE68FAC),
            c("Maple",  0xB85C6C), c("Rice",  0xF5DEB3),
            c("Bamboo", 0x6B8E23)]),

        P("Moroccan", "globe.asia.australia.fill", .cultural, [
            c("Henna", 0xC7372F), c("Saffron", 0xF3A847),
            c("Teal",  0x4A8C8B), c("Indigo",  0x5B3C88),
            c("Sand",  0xF5E6D3)]),

        P("Scandinavian", "snowflake", .cultural, [
            c("Snow",   0xFFFFFF), c("Linen",  0xF0E6D6),
            c("Stone",  0xB8C5C5), c("Slate",  0x6B7280),
            c("Charcoal", 0x1F2937)]),

        P("Mediterranean", "sailboat.fill", .cultural, [
            c("Azure", 0x3B82F6), c("Sky",    0xDBEAFE),
            c("Lemon", 0xFCD34D), c("Tomato", 0xDC2626),
            c("Lime",  0xFFFFFF)]),
    ]

    /// All palettes grouped by category — convenient for sectioned UIs.
    static var byCategory: [(category: PaletteCategory, palettes: [Palette])] {
        PaletteCategory.allCases
            .filter { $0 != .custom }       // .custom comes from PaletteStore
            .map { cat in (cat, library.filter { $0.category == cat }) }
    }
}
