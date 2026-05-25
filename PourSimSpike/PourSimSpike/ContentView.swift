import SwiftUI
import simd

// ---------------------------------------------------------------------------
// Tool model — module-level so FluidSimulator, Renderer, and CanvasView see it.
// ---------------------------------------------------------------------------
enum Tool: String, CaseIterable, Identifiable {
    case pour, swipe, stir, string, balloon, air, cup

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pour:    return "Pour"
        case .swipe:   return "Swipe"
        case .stir:    return "Stir"
        case .string:  return "String"
        case .balloon: return "Balloon"
        case .air:     return "Air"
        case .cup:     return "Cup"
        }
    }

    var icon: String {
        switch self {
        case .pour:    return "drop.fill"
        case .swipe:   return "hand.draw.fill"
        case .stir:    return "tornado"
        case .string:  return "line.diagonal"
        case .balloon: return "circle.dashed.inset.filled"
        case .air:     return "wind"
        case .cup:     return "cup.and.saucer.fill"
        }
    }

    /// Default radius (cells). Overridden by the active ToolVariant when set.
    var radius: Float {
        switch self {
        case .pour:    return 14
        case .swipe:   return 18
        case .stir:    return 28
        case .string:  return 2
        case .balloon: return 28
        case .air:     return 28
        case .cup:     return 60
        }
    }

    /// Tools that inject paint show the color/palette picker as secondary nav.
    /// Others show their variant picker.
    var usesColor: Bool { self == .pour || self == .balloon || self == .cup }
}

// ---------------------------------------------------------------------------
// ToolVariant — sub-options for each tool (palette-knife shape, string type,
// air source, cup style, etc.). Selected via the bottom secondary nav.
// ---------------------------------------------------------------------------
struct ToolVariant: Identifiable, Equatable, Hashable {
    let id:     String
    let name:   String
    let icon:   String
    let radius: Float
    let force:  Float
}

extension Tool {
    var variants: [ToolVariant] {
        switch self {
        case .pour: return []   // Pour's secondary nav is colors, not variants
        case .swipe: return [
            .init(id: "knife",  name: "Palette Knife", icon: "rectangle.compress.vertical", radius: 18, force: 1.0),
            .init(id: "card",   name: "Wide Card",     icon: "rectangle.fill",              radius: 38, force: 0.85),
            .init(id: "comb",   name: "Comb",          icon: "lineweight",                  radius: 24, force: 0.55),
            .init(id: "finger", name: "Finger",        icon: "hand.point.up.left.fill",     radius: 8,  force: 1.25),
        ]
        case .stir: return [
            .init(id: "swirl",     name: "Swirl",      icon: "tornado",                       radius: 28, force: 1.0),
            .init(id: "whirlpool", name: "Whirlpool",  icon: "hurricane",                     radius: 52, force: 1.25),
            .init(id: "quick",     name: "Quick Stir", icon: "arrow.triangle.2.circlepath",   radius: 16, force: 0.8),
        ]
        case .string: return [
            .init(id: "thin",  name: "Thin",  icon: "line.diagonal",      radius: 1.5, force: 0.85),
            .init(id: "thick", name: "Thick", icon: "lineweight",         radius: 3.0, force: 1.0),
            .init(id: "yarn",  name: "Yarn",  icon: "scribble",           radius: 4.0, force: 0.6),
            .init(id: "wire",  name: "Wire",  icon: "minus",              radius: 1.0, force: 1.5),
        ]
        case .balloon: return [
            .init(id: "small",  name: "Small",  icon: "circle.fill",             radius: 14, force: 1.0),
            .init(id: "medium", name: "Medium", icon: "circle.circle.fill",      radius: 28, force: 1.0),
            .init(id: "large",  name: "Large",  icon: "circle.hexagongrid.fill", radius: 50, force: 1.0),
        ]
        case .air: return [
            .init(id: "dryer",      name: "Hair Dryer", icon: "wind",        radius: 32, force: 1.0),
            .init(id: "compressor", name: "Compressor", icon: "wind.snow",   radius: 16, force: 2.0),
            .init(id: "straw",      name: "Straw",      icon: "lineweight",  radius: 6,  force: 1.4),
        ]
        case .cup: return [
            .init(id: "flip",  name: "Flip Cup",   icon: "cup.and.saucer.fill",         radius: 70, force: 1.0),
            .init(id: "open",  name: "Open Pour",  icon: "drop.triangle.fill",          radius: 45, force: 1.0),
            .init(id: "dirty", name: "Dirty Pour", icon: "drop.fill.viewfinder",        radius: 35, force: 1.0),
        ]
        }
    }
}

// ---------------------------------------------------------------------------
// RootView — home screen + canvas navigation
// ---------------------------------------------------------------------------
struct RootView: View {
    @StateObject private var paletteStore = PaletteStore()
    @State private var showFlow    = false
    @State private var showGallery = false

    var body: some View {
        HomeView(paletteStore: paletteStore,
                 onNewPour:  { showFlow    = true },
                 onMyArt:    { showGallery = true })
            .fullScreenCover(isPresented: $showFlow) {
                PourFlowView(paletteStore: paletteStore,
                             onDone: { showFlow = false })
            }
            .sheet(isPresented: $showGallery) {
                GalleryView()
                    .presentationDetents([.large])
            }
    }
}

// ---------------------------------------------------------------------------
// HomeView — launch screen before the canvas
// ---------------------------------------------------------------------------
struct HomeView: View {
    @ObservedObject var paletteStore: PaletteStore
    var onNewPour: () -> Void
    var onMyArt:   () -> Void

    @State private var showBalanceTest = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Wordmark
                VStack(spacing: 8) {
                    Text("Pour Art")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("A real fluid painting simulator")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                }

                // Last-used palette preview
                HStack(spacing: 10) {
                    ForEach(paletteStore.activePalette.colors) { color in
                        Circle()
                            .fill(color.displayColor)
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                    }
                }
                .padding(.top, 40)

                Text(paletteStore.activePalette.name)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 6)

                Spacer()

                // Actions
                VStack(spacing: 14) {
                    Button(action: onNewPour) {
                        Label("New Pour", systemImage: "drop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button(action: onMyArt) {
                        Label("See My Art", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }

            // Bottom-right tilt-test button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showBalanceTest = true
                    } label: {
                        Text("t")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.06))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .fullScreenCover(isPresented: $showBalanceTest) {
            BalanceTestView()
        }
    }
}

// ---------------------------------------------------------------------------
// CanvasContainerView — wraps the canvas + all HUD elements
// ---------------------------------------------------------------------------
struct CanvasContainerView: View {

    @ObservedObject var paletteStore: PaletteStore
    var consistency: Float = 0   // -1 (thin) … +1 (thick), averaged from PaintSetupView
    var canvasShape: CanvasShape = .portrait
    var onExit: () -> Void

    @StateObject private var motion = MotionService()
    @State private var activeTool: Tool       = .pour
    @State private var showPalettePicker      = false
    @State private var editingSlotIndex: Int? = nil
    @State private var renderer: Renderer?    = nil
    @State private var showFinishAlert        = false
    @State private var previewImage: UIImage? = nil
    @State private var neutralSelected: Int?  = nil
    @State private var showNeutrals: Bool     = false
    @State private var toolVariants: [Tool: ToolVariant] = [:]

    var body: some View {
        ZStack {
            CanvasView(motion: motion,
                       injectColor: paletteStore.activeColor,
                       activeTool: $activeTool,
                       onFPS: { _ in },
                       onRendererReady: { r in
                           self.renderer = r
                           r.applyCanvasShape(canvasShape)
                           r.fillBase(rgb: paletteStore.baseColor)
                           r.applyConsistency(consistency)
                           syncToolToRenderer()
                       })
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── TOP: tool selector + menu ─────────────────────────────
                HStack(alignment: .center, spacing: 8) {
                    ToolSelectorButton(activeTool: $activeTool)
                    Spacer(minLength: 4)
                    menuButton
                }
                .padding(.horizontal, 10)
                .padding(.top, 0)

                Spacer()

                // ── BOTTOM: tool-specific secondary nav ───────────────────
                // Tools with variants always show their variant picker first.
                // Color-injecting tools (Pour/Balloon/Cup) additionally show
                // the palette swatch row below it.
                VStack(spacing: 8) {
                    if !activeTool.variants.isEmpty {
                        secondaryVariantRow
                    }
                    if activeTool.usesColor && showNeutrals {
                        neutralRow
                            .padding(.horizontal, 10)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if activeTool.usesColor {
                        secondaryColorRow
                    }
                }
                .padding(.bottom, 0)
            }
            .animation(.easeInOut(duration: 0.2), value: activeTool)
            .animation(.easeInOut(duration: 0.2), value: showNeutrals)
        }
        .onChange(of: activeTool) { _, _ in syncToolToRenderer() }
        .onDisappear { motion.stop() }
        // Palette picker sheet
        .sheet(isPresented: $showPalettePicker) {
            PalettePickerView(store: paletteStore, onSelect: nil)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Color slot editor — long-press on a swatch
        .sheet(item: Binding(
            get: { editingSlotIndex.map { ColorEditTarget(index: $0) } },
            set: { editingSlotIndex = $0?.index }
        )) { target in
            ColorSlotEditorView(
                store: paletteStore,
                slotIndex: target.index
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        // Finish confirm
        .alert("Finish Pour?", isPresented: $showFinishAlert) {
            Button("Finish", role: .none) {
                previewImage = renderer?.captureImage()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Capture your painting and go to the preview screen.")
        }
        // Preview
        .fullScreenCover(item: Binding(
            get: { previewImage.map { FinishedPainting(image: $0) } },
            set: { if $0 == nil { previewImage = nil } }
        )) { painting in
            PreviewView(image: painting.image, onBackToCanvas: {
                previewImage = nil
            }, onDone: {
                previewImage = nil
                onExit()
            })
        }
    }

    // MARK: - Secondary nav (bottom)

    /// For color-injecting tools (Pour, Balloon, Cup): palette button +
    /// 5 swatches + a neutral toggle inside a capsule pill.
    private var secondaryColorRow: some View {
        HStack(spacing: 10) {
            Button {
                showPalettePicker = true
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }

            HStack(spacing: 8) {
                ForEach(Array(paletteStore.activePalette.colors.enumerated()),
                        id: \.element.id) { idx, color in
                    let isActive = (neutralSelected == nil
                                    && paletteStore.activeColorIndex == idx)
                    Circle()
                        .fill(color.displayColor)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(.white,
                                                 lineWidth: isActive ? 2.5 : 1))
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .onTapGesture {
                            paletteStore.activeColorIndex = idx
                            paletteStore.transientColor   = nil
                            neutralSelected = nil
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            editingSlotIndex = idx
                        }
                }
            }

            neutralToggleButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35))
        .clipShape(Capsule())
        .padding(.horizontal, 10)
    }

    /// For non-color tools (Swipe, Stir, String, Air, Wipe): horizontal
    /// scroll of variant chips for sub-tool selection.
    private var secondaryVariantRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(activeTool.variants) { variant in
                    let isSelected = selectedVariant(for: activeTool)?.id == variant.id
                    Button {
                        toolVariants[activeTool] = variant
                        syncToolToRenderer()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: variant.icon)
                                .font(.system(size: 15, weight: .semibold))
                            Text(variant.name)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(minWidth: 64)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.white : Color.black.opacity(0.5))
                        .foregroundStyle(isSelected ? Color.black : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.15), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private func selectedVariant(for tool: Tool) -> ToolVariant? {
        toolVariants[tool] ?? tool.variants.first
    }

    /// Push the current tool's selected variant (radius + force) into the
    /// renderer so the next sim step uses it.
    private func syncToolToRenderer() {
        guard let r = renderer else { return }
        let variant = selectedVariant(for: activeTool)
        r.toolRadius = variant?.radius ?? activeTool.radius
        r.toolForce  = variant?.force  ?? 1.0
    }

    // Pill that shows current neutral (or yin-yang) + chevron — taps expand
    private var neutralToggleButton: some View {
        Button {
            showNeutrals.toggle()
        } label: {
            HStack(spacing: 4) {
                if let i = neutralSelected, i < PaletteStore.neutralPalette.count {
                    let rgb = PaletteStore.neutralPalette[i]
                    Circle()
                        .fill(Color(red: Double(rgb.x),
                                    green: Double(rgb.y),
                                    blue: Double(rgb.z)))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 0.5))
                } else {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Image(systemName: showNeutrals ? "chevron.down" : "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(.black.opacity(0.45))
            .clipShape(Capsule())
        }
    }

    // Expanded neutral row (white / black / grays / metallics)
    private var neutralRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(PaletteStore.neutralPalette.enumerated()),
                    id: \.offset) { idx, rgb in
                let isActive = neutralSelected == idx
                Circle()
                    .fill(Color(red: Double(rgb.x),
                                green: Double(rgb.y),
                                blue: Double(rgb.z)))
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(.white,
                                             lineWidth: isActive ? 2.5 : 0.5))
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .onTapGesture {
                        paletteStore.selectNeutral(rgb)
                        neutralSelected = idx
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35))
        .clipShape(Capsule())
    }

    // Top-right ellipsis menu (Finish / Exit)
    private var menuButton: some View {
        Menu {
            Button {
                showFinishAlert = true
            } label: {
                Label("Finish & Preview", systemImage: "checkmark.circle.fill")
            }
            Divider()
            Button(role: .destructive) {
                onExit()
            } label: {
                Label("Exit Without Saving", systemImage: "xmark.circle.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 26))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.55))
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
    }
}

// Identifiable wrapper so .sheet(item:) works with Int.
private struct ColorEditTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

// Identifiable wrapper so .fullScreenCover(item:) works with UIImage.
private struct FinishedPainting: Identifiable {
    let image: UIImage
    let id = UUID()
}

// ---------------------------------------------------------------------------
// BaseColorPickerButton — custom circle that opens the system ColorPicker
// ---------------------------------------------------------------------------
struct BaseColorPickerButton: View {
    @ObservedObject var store: PaletteStore
    @State private var pickedColor: Color

    init(store: PaletteStore) {
        self.store = store
        let rgb = store.baseColor
        _pickedColor = State(initialValue:
            Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z)))
    }

    var body: some View {
        ColorPicker("", selection: $pickedColor, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 36, height: 36)
            .onChange(of: pickedColor) { _, newColor in
                if let comps = UIColor(newColor).cgColor.components, comps.count >= 3 {
                    store.setBaseColor(SIMD3(Float(comps[0]), Float(comps[1]), Float(comps[2])))
                }
            }
    }
}

// ---------------------------------------------------------------------------
// ToolbarView
// ---------------------------------------------------------------------------
// Pill at the top of the canvas showing the active tool. Tap to choose
// from every available tool.
struct ToolSelectorButton: View {
    @Binding var activeTool: Tool

    var body: some View {
        Menu {
            ForEach(Tool.allCases) { tool in
                Button {
                    activeTool = tool
                } label: {
                    Label(tool.displayName, systemImage: tool.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: activeTool.icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(activeTool.displayName)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(0.55)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.black.opacity(0.55))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
        }
    }
}

// ---------------------------------------------------------------------------
// PalettePickerView — browse and select a preset palette
// ---------------------------------------------------------------------------
struct PalettePickerView: View {
    @ObservedObject var store: PaletteStore
    var onSelect: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: PaletteCategory = .classic

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(visibleCategories, id: \.self) { cat in
                            CategoryChip(category: cat,
                                         isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.black.opacity(0.001))
                Divider().background(Color.white.opacity(0.1))

                List {
                    ForEach(palettesInCurrentCategory) { palette in
                        PaletteRowView(palette: palette,
                                       isSelected: store.activePalette.name == palette.name)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.select(palette: palette)
                                dismiss()
                                onSelect?()
                            }
                            .swipeActions(edge: .trailing) {
                                if palette.category == .custom {
                                    Button(role: .destructive) {
                                        store.deleteSavedPalette(palette)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }

                    if !store.recentColors.isEmpty && selectedCategory == .classic {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(store.recentColors) { color in
                                        Circle()
                                            .fill(color.displayColor)
                                            .frame(width: 38, height: 38)
                                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                            .onTapGesture {
                                                store.activePalette.colors[store.activeColorIndex] = color
                                                dismiss()
                                                onSelect?()
                                            }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        } header: {
                            Text("Recent Colors")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Palettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var visibleCategories: [PaletteCategory] {
        var cats = PaletteCategory.allCases.filter { $0 != .custom }
        if !store.savedPalettes.isEmpty { cats.append(.custom) }
        return cats
    }

    private var palettesInCurrentCategory: [Palette] {
        if selectedCategory == .custom { return store.savedPalettes }
        return Palette.library.filter { $0.category == selectedCategory }
    }
}

private struct CategoryChip: View {
    let category:   PaletteCategory
    let isSelected: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(category.label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isSelected ? Color.white : Color.white.opacity(0.1))
        .foregroundStyle(isSelected ? Color.black : Color.white)
        .clipShape(Capsule())
    }
}

// ---------------------------------------------------------------------------
// PaletteRowView — one row in the palette list
// ---------------------------------------------------------------------------
struct PaletteRowView: View {
    let palette: Palette
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: palette.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(palette.name)
                .font(.headline)

            Spacer()

            HStack(spacing: 5) {
                ForEach(palette.colors) { color in
                    Circle()
                        .fill(color.displayColor)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.5))
                }
            }

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// ---------------------------------------------------------------------------
// ColorSlotEditorView — long-press a swatch → pick a custom color
// ---------------------------------------------------------------------------
struct ColorSlotEditorView: View {
    @ObservedObject var store: PaletteStore
    let slotIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var pickedColor: Color

    init(store: PaletteStore, slotIndex: Int) {
        self.store     = store
        self.slotIndex = slotIndex
        let rgb = store.activePalette.colors[slotIndex].rgb
        _pickedColor = State(initialValue:
            Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Preview
                HStack(spacing: 12) {
                    ForEach(Array(store.activePalette.colors.enumerated()),
                            id: \.element.id) { idx, color in
                        Circle()
                            .fill(idx == slotIndex ? pickedColor : color.displayColor)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle().stroke(.white, lineWidth: idx == slotIndex ? 3 : 1)
                            )
                    }
                }
                .padding(.top, 16)

                ColorPicker("Slot \(slotIndex + 1) Color", selection: $pickedColor,
                            supportsOpacity: false)
                    .padding(.horizontal, 24)

                // Recents quick-pick
                if !store.recentColors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(store.recentColors) { color in
                                    Circle()
                                        .fill(color.displayColor)
                                        .frame(width: 36, height: 36)
                                        .onTapGesture {
                                            pickedColor = color.displayColor
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Edit Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        store.setColor(pickedColor, at: slotIndex)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
