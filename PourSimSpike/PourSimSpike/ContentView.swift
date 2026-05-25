import SwiftUI
import simd

// ---------------------------------------------------------------------------
// Tool model — module-level so FluidSimulator, Renderer, and CanvasView see it.
// ---------------------------------------------------------------------------
enum Tool: String, CaseIterable, Identifiable {
    case pour, drop, thinner, thickener, wipe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pour:      return "Pour"
        case .drop:      return "Drop"
        case .thinner:   return "Thinner"
        case .thickener: return "Thickener"
        case .wipe:      return "Wipe"
        }
    }

    var icon: String {
        switch self {
        case .pour:      return "drop.fill"
        case .drop:      return "circle.inset.filled"
        case .thinner:   return "wind"
        case .thickener: return "seal.fill"
        case .wipe:      return "eraser.fill"
        }
    }

    var radius: Float {
        switch self {
        case .pour:      return 14
        case .drop:      return 6
        case .thinner:   return 20
        case .thickener: return 16
        case .wipe:      return 22
        }
    }

    var usesColor: Bool { self == .pour || self == .drop }
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
        }
    }
}

// ---------------------------------------------------------------------------
// CanvasContainerView — wraps the canvas + all HUD elements
// ---------------------------------------------------------------------------
struct CanvasContainerView: View {

    @ObservedObject var paletteStore: PaletteStore
    var consistency: Float = 0   // -1 (thin) … +1 (thick), averaged from PaintSetupView
    var onExit: () -> Void

    @StateObject private var motion = MotionService()
    @State private var fps: Double            = 0
    @State private var activeTool: Tool       = .pour
    @State private var showPalettePicker      = false
    @State private var editingSlotIndex: Int? = nil
    @State private var renderer: Renderer?    = nil
    @State private var showFinishAlert        = false
    @State private var previewImage: UIImage? = nil

    var body: some View {
        ZStack {
            CanvasView(motion: motion,
                       injectColor: paletteStore.activeColor,
                       activeTool: $activeTool,
                       onFPS: { fps in self.fps = fps },
                       onRendererReady: { r in
                           self.renderer = r
                           r.fillBase(rgb: paletteStore.baseColor)
                           r.applyConsistency(consistency)
                       })
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text(String(format: "%.0f fps", fps))
                        .font(.system(.caption, design: .monospaced))
                        .padding(6)
                        .background(.black.opacity(0.5))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Button("Finish") {
                        showFinishAlert = true
                    }
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        onExit()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 12)
                .padding(.top, 60)

                // Palette row — visible only for color tools
                if activeTool.usesColor {
                    HStack(spacing: 0) {
                        // Palette picker button
                        Button {
                            showPalettePicker = true
                        } label: {
                            Image(systemName: "paintpalette.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.leading, 12)

                        // Color swatches — tap = select, long-press = edit
                        HStack(spacing: 10) {
                            ForEach(Array(paletteStore.activePalette.colors.enumerated()),
                                    id: \.element.id) { idx, color in
                                Circle()
                                    .fill(color.displayColor)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle().stroke(.white,
                                                        lineWidth: paletteStore.activeColorIndex == idx ? 3 : 1)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                                    .onTapGesture {
                                        paletteStore.activeColorIndex = idx
                                    }
                                    .onLongPressGesture(minimumDuration: 0.5) {
                                        editingSlotIndex = idx
                                    }
                            }
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 12)
                    }
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                ToolbarView(activeTool: $activeTool)
                    .padding(.bottom, 40)
            }
            .animation(.easeInOut(duration: 0.2), value: activeTool)
        }
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
struct ToolbarView: View {
    @Binding var activeTool: Tool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Tool.allCases) { tool in
                Button {
                    activeTool = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.title3)
                        Text(tool.displayName)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(activeTool == tool
                                ? Color.white.opacity(0.25)
                                : Color.black.opacity(0.45))
                    .foregroundStyle(activeTool == tool ? .white : .white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(activeTool == tool ? Color.white.opacity(0.6) : .clear,
                                    lineWidth: 1.5)
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
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
