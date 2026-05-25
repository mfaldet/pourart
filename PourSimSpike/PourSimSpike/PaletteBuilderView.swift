import SwiftUI
import simd

// ---------------------------------------------------------------------------
// PaletteBuilderView — three-mode color palette builder.
//
// • Harmony — color wheel + harmony rules generate 5 colors automatically
// • Image   — extract a palette from a photo
// • Custom  — build slot by slot via the detail editor
//
// Slot state persists across mode switches. Lock icons preserve individual
// slots when harmony / image extraction would overwrite them.
// ---------------------------------------------------------------------------
struct PaletteBuilderView: View {
    @ObservedObject var store: PaletteStore

    // Builder mode
    @State private var mode: BuilderMode = .harmony

    // Harmony state
    @State private var hue:        Double = 0.6
    @State private var saturation: Double = 0.75
    @State private var brightness: Double = 0.90
    @State private var harmony:    ColorHarmony = .analogous

    // Slot state — source of truth for the canvas palette
    @State private var paletteSlots: [SIMD3<Float>] = Array(repeating: SIMD3(1, 1, 1), count: 5)
    @State private var lockedSlots:  Set<Int>       = []

    // Image mode
    @State private var sourceImage:    UIImage? = nil
    @State private var showPhotoPicker         = false

    // Slot editor (long-press a slot)
    @State private var editingSlot: Int? = nil

    // Save palette sheet
    @State private var showSaveSheet   = false
    @State private var saveName        = ""

    // Preset picker (Load button)
    @State private var showPresets     = false

    enum BuilderMode: String, CaseIterable, Identifiable {
        case harmony, image, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .harmony: return "Harmony"
            case .image:   return "Image"
            case .custom:  return "Custom"
            }
        }
        var icon: String {
            switch self {
            case .harmony: return "circle.hexagongrid.fill"
            case .image:   return "photo.fill"
            case .custom:  return "paintbrush.pointed.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                header
                modeTabs

                Group {
                    switch mode {
                    case .harmony: harmonyMode
                    case .image:   imageMode
                    case .custom:  customMode
                    }
                }

                // Always-visible slot strip & actions
                slotStrip

                quickActions

                paletteAdjustToolbar

                colorBlindnessPreview

                ScienceInfoCard(harmony: harmony)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .onAppear { regenerateUnlocked() }
        .onChange(of: hue)        { _, _ in if mode == .harmony { regenerateUnlocked() } }
        .onChange(of: saturation) { _, _ in if mode == .harmony { regenerateUnlocked() } }
        .onChange(of: brightness) { _, _ in if mode == .harmony { regenerateUnlocked() } }
        .onChange(of: harmony)    { _, _ in if mode == .harmony { regenerateUnlocked() } }
        .onChange(of: paletteSlots) { _, _ in syncToStore() }
        .onChange(of: sourceImage) { _, img in
            if let img { extractFromImage(img) }
        }
        // Sheets
        .sheet(item: Binding(
            get: { editingSlot.map { SlotIndex(index: $0) } },
            set: { editingSlot = $0?.index }
        )) { idx in
            PaletteSlotEditor(rgb: slotBinding(for: idx.index))
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerSheet(image: $sourceImage)
        }
        .sheet(isPresented: $showSaveSheet) {
            SavePaletteSheet(name: $saveName) { name in
                let colors = paletteSlots.enumerated().map { i, rgb in
                    PaletteColor(name: "Color \(i+1)", rgb: rgb)
                }
                store.savePalette(name: name, colors: colors)
                saveName = ""
            }
            .presentationDetents([.height(220)])
        }
        .sheet(isPresented: $showPresets) {
            PalettePickerView(store: store, onSelect: nil)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onDisappear {
                    // Pull active palette into slots
                    paletteSlots = store.activePalette.colors.map(\.rgb)
                    lockedSlots.removeAll()
                }
        }
    }

    // MARK: - Header / mode tabs

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Build Your Palette")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Tap a slot to edit · Tap the lock to pin a color in place.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 20)
    }

    private var modeTabs: some View {
        HStack(spacing: 0) {
            ForEach(BuilderMode.allCases) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { mode = m }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                        Text(m.label)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(mode == m ? Color.white.opacity(0.16) : Color.clear)
                    .foregroundStyle(mode == m ? .white : .white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(4)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Harmony mode

    private var harmonyMode: some View {
        VStack(spacing: 18) {
            // Harmony chips
            VStack(alignment: .leading, spacing: 8) {
                Text("Harmony")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ColorHarmony.allCases) { h in
                            HarmonyChip(harmony: h, isSelected: harmony == h)
                                .onTapGesture { harmony = h }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                Text(harmony.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 20)
            }

            // Wheel + sliders
            VStack(spacing: 14) {
                ColorWheelPicker(hue: $hue, saturation: $saturation)
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    LabeledSlider(label: "Brightness", value: $brightness, range: 0.2...1.0,
                                  tint: Color(hue: hue, saturation: saturation, brightness: brightness),
                                  format: { "\(Int($0 * 100))%" })
                    LabeledSlider(label: "Saturation", value: $saturation, range: 0.0...1.0,
                                  tint: Color(hue: hue, saturation: saturation, brightness: 0.9),
                                  format: { "\(Int($0 * 100))%" })
                }
                .padding(.horizontal, 20)

                HStack(spacing: 16) {
                    TemperatureLabel(hue: hue)
                    Spacer()
                    Text("Hue \(Int(hue * 360))°")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Image mode

    private var imageMode: some View {
        VStack(spacing: 16) {
            Text("Pour artists often draw color inspiration from photos — sunsets, gardens, vintage prints. Pick an image to extract its colors automatically.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 20)

            if let img = sourceImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.1)))
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Choose Different", systemImage: "photo")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.1))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        if let img = sourceImage { extractFromImage(img) }
                    } label: {
                        Label("Re-extract", systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
            } else {
                Button {
                    showPhotoPicker = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.fill.on.rectangle.fill")
                            .font(.system(size: 36))
                        Text("Pick a Photo")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(.white.opacity(0.2)))
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Custom mode

    private var customMode: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How to use Custom mode", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            VStack(alignment: .leading, spacing: 6) {
                customBullet("Tap a swatch → full color editor (HSB, hex, tints, shades, tones)")
                customBullet("Tap the 🔒 → lock a slot so Randomize / Match won't change it")
                customBullet("Use the Adjust toolbar below to fine-tune the whole palette")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func customBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").opacity(0.5)
            Text(text)
        }
    }

    // MARK: - Slot strip (always visible)

    private var slotStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your Palette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showPresets = true
                } label: {
                    Label("Load", systemImage: "tray.and.arrow.down.fill")
                        .font(.caption.weight(.semibold))
                }
                .tint(.white.opacity(0.6))
                Button {
                    UIPasteboard.general.string = paletteSlots
                        .map { ColorTools.hex($0) }
                        .joined(separator: " ")
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                }
                .tint(.white.opacity(0.6))
                Button {
                    showSaveSheet = true
                } label: {
                    Label("Save", systemImage: "bookmark.fill")
                        .font(.caption.weight(.semibold))
                }
                .tint(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    SlotCell(
                        rgb: paletteSlots[i],
                        isLocked: lockedSlots.contains(i),
                        onTap:    { editingSlot = i },
                        onLock:   { toggleLock(i) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !lockedSlots.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("\(lockedSlots.count) locked — only unlocked slots will change")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.yellow.opacity(0.8))
                .padding(.horizontal, 22)
            }

            HStack(spacing: 8) {
                QuickActionButton(label: "Randomize", icon: "die.face.5.fill") {
                    randomizeUnlocked()
                }
                QuickActionButton(label: "Match",     icon: "wand.and.rays") {
                    matchFromLocked()
                }
                QuickActionButton(label: "Clear Locks", icon: "lock.open.fill") {
                    lockedSlots.removeAll()
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Lock-aware fillers

    private func randomizeUnlocked() {
        let generated = ColorTools.randomPalette(harmony: harmony)
        var next = paletteSlots
        for i in 0..<5 where !lockedSlots.contains(i) {
            next[i] = generated[i]
        }
        paletteSlots = next
    }

    /// Derive a hue from the locked colors, then fill unlocked slots
    /// using the current harmony rule. Falls back to a pure random
    /// fill if nothing is locked.
    private func matchFromLocked() {
        guard let firstLockedIdx = lockedSlots.sorted().first else {
            randomizeUnlocked()
            return
        }
        let base       = paletteSlots[firstLockedIdx]
        let (h, s, b)  = ColorTools.hsb(from: base)
        let generated  = harmony.paletteRGB(
            hue:        h,
            saturation: Swift.max(0.4, s),
            brightness: Swift.max(0.5, b))

        var next = paletteSlots
        // Generated[firstLockedIdx] is the base color — assign the OTHER
        // generated colors to unlocked positions in order.
        var pool = generated.enumerated()
            .filter { $0.offset != firstLockedIdx }
            .map { $0.element }
        for i in 0..<5 where !lockedSlots.contains(i) && !pool.isEmpty {
            next[i] = pool.removeFirst()
        }
        paletteSlots = next
    }

    // MARK: - Palette-wide adjustments

    private var paletteAdjustToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adjust Whole Palette")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                // Temperature rocker
                PairedAdjustButton(
                    top:    .init(label: "Warmer", icon: "thermometer.sun.fill",  tint: .orange) {
                        applyToUnlocked { ColorTools.rotateHue($0, by: 20) }
                    },
                    bottom: .init(label: "Cooler", icon: "thermometer.snowflake", tint: .cyan) {
                        applyToUnlocked { ColorTools.rotateHue($0, by: -20) }
                    })

                // Brightness rocker
                PairedAdjustButton(
                    top:    .init(label: "Lighten", icon: "sun.max.fill", tint: .yellow) {
                        applyToUnlocked { ColorTools.adjustBrightness($0, by: 0.08) }
                    },
                    bottom: .init(label: "Darken",  icon: "moon.fill",    tint: .indigo) {
                        applyToUnlocked { ColorTools.adjustBrightness($0, by: -0.08) }
                    })

                // Saturation rocker
                PairedAdjustButton(
                    top:    .init(label: "Saturate",   icon: "drop.fill", tint: .pink) {
                        applyToUnlocked { ColorTools.adjustSaturation($0, by: 0.12) }
                    },
                    bottom: .init(label: "Desaturate", icon: "drop",      tint: .gray) {
                        applyToUnlocked { ColorTools.adjustSaturation($0, by: -0.12) }
                    })

                // Reorder — visually separate (not a rocker)
                VStack(spacing: 6) {
                    AdjustButton(label: "Reverse", icon: "arrow.left.arrow.right", tint: .white) {
                        paletteSlots.reverse()
                        lockedSlots = Set(lockedSlots.map { 4 - $0 })
                    }
                    AdjustButton(label: "Shuffle", icon: "shuffle", tint: .white) {
                        var slots = paletteSlots
                        let unlocked = (0..<5).filter { !lockedSlots.contains($0) }
                        let shuffled = unlocked.shuffled()
                        for (i, dest) in unlocked.enumerated() {
                            slots[dest] = paletteSlots[shuffled[i]]
                        }
                        paletteSlots = slots
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var colorBlindnessPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Accessibility Preview", systemImage: "eye.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("how others see your palette")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 6) {
                ForEach(ColorBlindness.allCases) { type in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(type.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(type.subtitle)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(width: 96, alignment: .leading)

                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                let simulated = ColorTools.simulate(paletteSlots[i], type: type)
                                Color(red: Double(simulated.x),
                                      green: Double(simulated.y),
                                      blue: Double(simulated.z))
                                    .frame(maxWidth: .infinity, minHeight: 26)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func applyToUnlocked(_ transform: (SIMD3<Float>) -> SIMD3<Float>) {
        var next = paletteSlots
        for i in 0..<5 where !lockedSlots.contains(i) {
            next[i] = transform(paletteSlots[i])
        }
        paletteSlots = next
    }

    // MARK: - Actions

    private func regenerateUnlocked() {
        let generated = harmony.paletteRGB(hue: hue, saturation: saturation, brightness: brightness)
        var next = paletteSlots
        if next.count < 5 { next = generated }
        for i in 0..<5 where !lockedSlots.contains(i) {
            next[i] = generated[i]
        }
        if next != paletteSlots { paletteSlots = next }
    }

    private func toggleLock(_ i: Int) {
        if lockedSlots.contains(i) { lockedSlots.remove(i) }
        else                        { lockedSlots.insert(i) }
    }

    private func extractFromImage(_ image: UIImage) {
        let extracted = ColorTools.extractPalette(from: image, count: 5)
        guard extracted.count == 5 else { return }
        var next = paletteSlots
        for i in 0..<5 where !lockedSlots.contains(i) {
            next[i] = extracted[i]
        }
        paletteSlots = next
    }

    private func syncToStore() {
        let colors = paletteSlots.enumerated().map { i, rgb in
            PaletteColor(name: "Color \(i+1)", rgb: rgb)
        }
        store.setCustomColors(colors)
    }

    private func slotBinding(for index: Int) -> Binding<SIMD3<Float>> {
        Binding(
            get: { paletteSlots[index] },
            set: {
                paletteSlots[index] = $0
                lockedSlots.insert(index)   // editing locks the slot
            }
        )
    }
}

// ---------------------------------------------------------------------------
// SlotCell — one swatch in the palette strip.
// ---------------------------------------------------------------------------
private struct SlotCell: View {
    let rgb:      SIMD3<Float>
    let isLocked: Bool
    let onTap:    () -> Void
    let onLock:   () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
                    .frame(height: 78)
                Text(ColorTools.hex(rgb))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(.black)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.15), lineWidth: 1))
            .onTapGesture { onTap() }

            Button(action: onLock) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isLocked ? .black : .white)
                    .padding(5)
                    .background(isLocked ? Color.yellow : Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(5)
        }
    }
}

// ---------------------------------------------------------------------------
// SavePaletteSheet — name your custom palette and save it.
// ---------------------------------------------------------------------------
private struct SavePaletteSheet: View {
    @Binding var name: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Palette name", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    onSave(name)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.gray
                                    : Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Save Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Identifiable wrapper for .sheet(item:) over Int
private struct SlotIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

// ---------------------------------------------------------------------------
// ColorWheelPicker — interactive hue + saturation picker.
// ---------------------------------------------------------------------------
struct ColorWheelPicker: View {
    @Binding var hue:        Double
    @Binding var saturation: Double

    private var hueColors: [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0/12.0)
            .map { Color(hue: $0, saturation: 1, brightness: 1) }
        + [Color(hue: 0, saturation: 1, brightness: 1)]
    }

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let radius = size / 2

            ZStack {
                Circle().fill(AngularGradient(colors: hueColors, center: .center))
                Circle().fill(RadialGradient(
                    colors: [.white, .clear],
                    center: .center, startRadius: 0, endRadius: radius))
                Circle().stroke(.black.opacity(0.15), lineWidth: 1.5)

                let angle = hue * 2 * .pi
                let r     = saturation * radius
                Circle()
                    .fill(Color(hue: hue, saturation: saturation, brightness: 1))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .offset(x: cos(angle) * r, y: sin(angle) * r)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let dx   = v.location.x - size / 2
                let dy   = v.location.y - size / 2
                let dist = sqrt(dx*dx + dy*dy)
                guard dist <= radius else { return }
                let raw = atan2(dy, dx) / (2 * .pi)
                hue        = (raw + 1).truncatingRemainder(dividingBy: 1)
                saturation = dist / radius
            })
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// ---------------------------------------------------------------------------
// Reusable bits
// ---------------------------------------------------------------------------
struct HarmonyChip: View {
    let harmony:    ColorHarmony
    let isSelected: Bool
    var body: some View {
        Text(harmony.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.white.opacity(0.1))
            .foregroundStyle(isSelected ? Color.black : Color.white)
            .clipShape(Capsule())
    }
}

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let tint:  Color
    let format: (Double) -> String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(format(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }
            Slider(value: $value, in: range).tint(tint)
        }
    }
}

struct TemperatureLabel: View {
    let hue: Double
    private var label: String {
        switch hue {
        case 0..<0.08, 0.92...: return "Very Warm"
        case 0.08..<0.17:       return "Warm"
        case 0.17..<0.28:       return "Warm-Neutral"
        case 0.28..<0.42:       return "Neutral"
        case 0.42..<0.62:       return "Cool"
        case 0.62..<0.80:       return "Very Cool"
        default:                return "Cool"
        }
    }
    private var labelColor: Color {
        switch label {
        case "Very Warm": return .orange
        case "Warm":      return Color(hue: 0.07, saturation: 0.8, brightness: 1)
        case "Very Cool": return .blue
        case "Cool":      return .cyan
        default:          return .white.opacity(0.6)
        }
    }
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "thermometer.medium")
            Text(label)
        }
        .font(.caption)
        .foregroundStyle(labelColor)
    }
}

struct QuickActionButton: View {
    let label:  String
    let icon:   String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white.opacity(0.12))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// Config for one half of a PairedAdjustButton (or a standalone AdjustButton)
struct AdjustConfig {
    let label:  String
    let icon:   String
    let tint:   Color
    let action: () -> Void
}

// A standalone "remote-style" pill — used for buttons that aren't part
// of an attached pair (e.g. Reverse, Shuffle).
struct AdjustButton: View {
    let label:  String
    let icon:   String
    let tint:   Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(0.25), lineWidth: 1))
        }
    }
}

// Two buttons fused into a single capsule (a "rocker" like Volume+ / Volume-).
// Inner divider visually attaches the two; the whole shape has one rounded
// outline so the pair reads as related opposites.
struct PairedAdjustButton: View {
    let top:    AdjustConfig
    let bottom: AdjustConfig

    var body: some View {
        VStack(spacing: 0) {
            half(config: top)
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)
            half(config: bottom)
        }
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(.white.opacity(0.18), lineWidth: 1))
    }

    private func half(config: AdjustConfig) -> some View {
        Button(action: config.action) {
            VStack(spacing: 3) {
                Image(systemName: config.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(config.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(config.tint)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
    }
}

struct ScienceInfoCard: View {
    let harmony: ColorHarmony
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Color Science", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(harmony.scienceTip)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
