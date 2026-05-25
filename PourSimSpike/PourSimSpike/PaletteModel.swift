import SwiftUI
import simd

// ---------------------------------------------------------------------------
// PaletteColor — a single named color slot in a palette.
// ---------------------------------------------------------------------------
struct PaletteColor: Identifiable, Equatable {
    var id    = UUID()
    var name:  String
    var rgb:   SIMD3<Float>

    var displayColor: Color {
        Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
    }

    // Build from a SwiftUI Color (uses UIColor to extract linear-sRGB components).
    init(name: String, color: Color) {
        self.name = name
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.rgb = SIMD3(Float(r), Float(g), Float(b))
    }

    init(name: String, rgb: SIMD3<Float>) {
        self.name = name
        self.rgb  = rgb
    }

    init(name: String, r: Float, g: Float, b: Float) {
        self.name = name
        self.rgb  = SIMD3(r, g, b)
    }
}

// ---------------------------------------------------------------------------
// PaletteCategory — used to group presets in the picker.
// ---------------------------------------------------------------------------
enum PaletteCategory: String, CaseIterable, Identifiable, Codable {
    case classic, nature, mood, artist, era, cultural, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic:  return "Classic"
        case .nature:   return "Nature"
        case .mood:     return "Mood"
        case .artist:   return "Artist-Inspired"
        case .era:      return "Era"
        case .cultural: return "Cultural"
        case .custom:   return "Saved"
        }
    }

    var icon: String {
        switch self {
        case .classic:  return "star.fill"
        case .nature:   return "leaf.fill"
        case .mood:     return "heart.fill"
        case .artist:   return "paintbrush.fill"
        case .era:      return "clock.arrow.circlepath"
        case .cultural: return "globe"
        case .custom:   return "bookmark.fill"
        }
    }
}

// ---------------------------------------------------------------------------
// Palette — 5-color named palette with an SF Symbol icon.
// ---------------------------------------------------------------------------
struct Palette: Identifiable, Equatable {
    var id       = UUID()
    var name:    String
    var icon:    String           // SF Symbol
    var category: PaletteCategory = .classic
    var colors:  [PaletteColor]   // always 5

    static func == (lhs: Palette, rhs: Palette) -> Bool { lhs.id == rhs.id }
}

// ---------------------------------------------------------------------------
// Presets
// ---------------------------------------------------------------------------
extension Palette {
    static let ocean = Palette(name: "Ocean", icon: "water.waves", category: .classic, colors: [
        PaletteColor(name: "Navy",  r: 0.05, g: 0.10, b: 0.30),
        PaletteColor(name: "Teal",  r: 0.10, g: 0.55, b: 0.55),
        PaletteColor(name: "Sky",   r: 0.40, g: 0.72, b: 0.92),
        PaletteColor(name: "Foam",  r: 0.95, g: 0.96, b: 0.98),
        PaletteColor(name: "Gold",  r: 0.95, g: 0.75, b: 0.30),
    ])

    static let sunset = Palette(name: "Sunset", icon: "sun.horizon.fill", category: .classic, colors: [
        PaletteColor(name: "Crimson", r: 0.55, g: 0.05, b: 0.12),
        PaletteColor(name: "Coral",   r: 0.90, g: 0.35, b: 0.22),
        PaletteColor(name: "Amber",   r: 0.96, g: 0.62, b: 0.08),
        PaletteColor(name: "Peach",   r: 0.98, g: 0.82, b: 0.65),
        PaletteColor(name: "Violet",  r: 0.38, g: 0.08, b: 0.52),
    ])

    static let earth = Palette(name: "Earth", icon: "leaf.fill", category: .classic, colors: [
        PaletteColor(name: "Umber",   r: 0.28, g: 0.16, b: 0.08),
        PaletteColor(name: "Sienna",  r: 0.60, g: 0.30, b: 0.12),
        PaletteColor(name: "Ochre",   r: 0.80, g: 0.58, b: 0.18),
        PaletteColor(name: "Cream",   r: 0.94, g: 0.89, b: 0.72),
        PaletteColor(name: "Moss",    r: 0.20, g: 0.36, b: 0.16),
    ])

    static let neon = Palette(name: "Neon", icon: "bolt.fill", category: .classic, colors: [
        PaletteColor(name: "Electric", r: 0.00, g: 0.38, b: 1.00),
        PaletteColor(name: "Lime",     r: 0.12, g: 1.00, b: 0.28),
        PaletteColor(name: "Hot Pink", r: 1.00, g: 0.05, b: 0.58),
        PaletteColor(name: "Yellow",   r: 1.00, g: 0.95, b: 0.00),
        PaletteColor(name: "Purple",   r: 0.58, g: 0.00, b: 1.00),
    ])

    static let mono = Palette(name: "Mono", icon: "circle.lefthalf.filled", category: .classic, colors: [
        PaletteColor(name: "Ink",    r: 0.06, g: 0.06, b: 0.06),
        PaletteColor(name: "Slate",  r: 0.26, g: 0.26, b: 0.26),
        PaletteColor(name: "Steel",  r: 0.50, g: 0.50, b: 0.50),
        PaletteColor(name: "Silver", r: 0.78, g: 0.78, b: 0.78),
        PaletteColor(name: "White",  r: 0.96, g: 0.96, b: 0.96),
    ])

    static let pastel = Palette(name: "Pastel", icon: "sparkles", category: .classic, colors: [
        PaletteColor(name: "Lavender", r: 0.76, g: 0.66, b: 0.92),
        PaletteColor(name: "Mint",     r: 0.64, g: 0.90, b: 0.78),
        PaletteColor(name: "Blush",    r: 0.96, g: 0.74, b: 0.80),
        PaletteColor(name: "Butter",   r: 0.98, g: 0.95, b: 0.68),
        PaletteColor(name: "Sky",      r: 0.70, g: 0.86, b: 0.96),
    ])

    /// All built-in palettes (classic + extended library from PalettePresets.swift).
    static var all: [Palette] { library }
}

// ---------------------------------------------------------------------------
// PaletteStore — observable store; source of truth for palette + recents.
// ---------------------------------------------------------------------------
@MainActor
final class PaletteStore: ObservableObject {

    @Published var activePalette:    Palette        = .ocean
    @Published var activeColorIndex: Int            = 0
    @Published var recentColors:     [PaletteColor] = []
    @Published var baseColor:        SIMD3<Float>   = SIMD3(1, 1, 1)  // white default
    @Published var savedPalettes:    [Palette]      = []
    @Published var transientColor:   SIMD3<Float>?  = nil  // set when neutral row tapped

    var activeColor: SIMD3<Float> {
        transientColor ?? activePalette.colors[activeColorIndex].rgb
    }

    static let basePresets: [(name: String, rgb: SIMD3<Float>)] = [
        ("White",     SIMD3(1.00, 1.00, 1.00)),
        ("Cream",     SIMD3(0.98, 0.95, 0.88)),
        ("Lt. Gray",  SIMD3(0.75, 0.75, 0.75)),
        ("Black",     SIMD3(0.05, 0.05, 0.05)),
    ]

    /// Neutral palette — always available on the canvas alongside the custom
    /// palette so artists can mix in highlights, shadows, and metallics
    /// without rebuilding their main palette.
    static let neutralPalette: [SIMD3<Float>] = [
        SIMD3(0.99, 0.99, 0.99),  // Pure white — highlights & cells
        SIMD3(0.04, 0.04, 0.04),  // Black — shadows & contrast
        SIMD3(0.78, 0.78, 0.78),  // Light gray
        SIMD3(0.36, 0.36, 0.36),  // Dark gray
        SIMD3(0.83, 0.69, 0.22),  // Gold — metallic accent
        SIMD3(0.75, 0.75, 0.78),  // Silver — metallic accent
    ]

    /// Switch the active color to a transient (off-palette) RGB value —
    /// used by the on-canvas neutral row. Does NOT modify the saved palette.
    func selectNeutral(_ rgb: SIMD3<Float>) {
        transientColor = rgb
    }

    private static let recentsKey = "pourart.v1.recentColors"
    private static let baseKey    = "pourart.v1.baseColor"
    private static let savedKey   = "pourart.v1.savedPalettes"

    init() {
        loadRecents()
        loadSavedPalettes()
        if let flat = UserDefaults.standard.array(forKey: Self.baseKey) as? [Float],
           flat.count == 3 {
            baseColor = SIMD3(flat[0], flat[1], flat[2])
        }
    }

    // MARK: - Saved palettes (user-created custom palettes)

    func savePalette(name: String, colors: [PaletteColor]) {
        guard !colors.isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let final   = trimmed.isEmpty ? "Untitled" : trimmed
        let palette = Palette(name: final, icon: "bookmark.fill",
                              category: .custom,
                              colors: Array(colors.prefix(5)))
        savedPalettes.insert(palette, at: 0)
        persistSavedPalettes()
    }

    func deleteSavedPalette(_ palette: Palette) {
        savedPalettes.removeAll { $0.id == palette.id }
        persistSavedPalettes()
    }

    private func persistSavedPalettes() {
        let codables = savedPalettes.map { p in
            CodablePalette(name: p.name, colors: p.colors.map {
                CodableColor(name: $0.name, r: $0.rgb.x, g: $0.rgb.y, b: $0.rgb.z)
            })
        }
        if let data = try? JSONEncoder().encode(codables) {
            UserDefaults.standard.set(data, forKey: Self.savedKey)
        }
    }

    private func loadSavedPalettes() {
        guard let data = UserDefaults.standard.data(forKey: Self.savedKey),
              let codables = try? JSONDecoder().decode([CodablePalette].self, from: data)
        else { return }
        savedPalettes = codables.map { cp in
            Palette(name: cp.name, icon: "bookmark.fill", category: .custom,
                    colors: cp.colors.map { PaletteColor(name: $0.name,
                                                         rgb: SIMD3($0.r, $0.g, $0.b)) })
        }
    }

    func setCustomColors(_ colors: [PaletteColor]) {
        guard !colors.isEmpty else { return }
        let slots = Array(colors.prefix(5))
        for (i, c) in slots.enumerated() where i < activePalette.colors.count {
            activePalette.colors[i] = c
        }
    }

    func setBaseColor(_ rgb: SIMD3<Float>) {
        baseColor = rgb
        UserDefaults.standard.set([rgb.x, rgb.y, rgb.z], forKey: Self.baseKey)
    }

    // Load a preset (resets the active color index to 0).
    func select(palette: Palette) {
        activePalette    = palette
        activeColorIndex = 0
    }

    // Replace one slot with a custom Color from SwiftUI ColorPicker.
    func setColor(_ color: Color, at index: Int) {
        guard index < activePalette.colors.count else { return }
        let pc = PaletteColor(name: "Custom", color: color)
        activePalette.colors[index] = pc
        addToRecents(pc)
    }

    func addToRecents(_ color: PaletteColor) {
        // Deduplicate by approximate RGB match (within 1/255).
        recentColors.removeAll {
            distance($0.rgb, color.rgb) < 0.005
        }
        recentColors.insert(color, at: 0)
        if recentColors.count > 10 { recentColors = Array(recentColors.prefix(10)) }
        saveRecents()
    }

    // MARK: - Persistence (recents only; full state lives in M6 CanvasStore)

    private func saveRecents() {
        let flat = recentColors.flatMap { [$0.rgb.x, $0.rgb.y, $0.rgb.z] }
        UserDefaults.standard.set(flat, forKey: Self.recentsKey)
    }

    private func loadRecents() {
        guard let flat = UserDefaults.standard.array(forKey: Self.recentsKey) as? [Float],
              flat.count % 3 == 0 else { return }
        recentColors = stride(from: 0, to: flat.count, by: 3).map { i in
            PaletteColor(name: "Custom", rgb: SIMD3(flat[i], flat[i+1], flat[i+2]))
        }
    }
}

// ---------------------------------------------------------------------------
// Codable helpers for saved-palette persistence
// ---------------------------------------------------------------------------
private struct CodableColor: Codable {
    let name: String
    let r:    Float
    let g:    Float
    let b:    Float
}

private struct CodablePalette: Codable {
    let name:   String
    let colors: [CodableColor]
}
