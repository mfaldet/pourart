import SwiftUI
import simd

// ---------------------------------------------------------------------------
// PaletteBuilderView — Step 1: color science palette builder.
// ---------------------------------------------------------------------------
struct PaletteBuilderView: View {
    @ObservedObject var store: PaletteStore

    @State private var hue:        Double = 0.6
    @State private var saturation: Double = 0.75
    @State private var brightness: Double = 0.90
    @State private var harmony:    ColorHarmony = .analogous
    @State private var showPresets = false

    private var generatedRGBs: [SIMD3<Float>] {
        harmony.paletteRGB(hue: hue, saturation: saturation, brightness: brightness)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Build Your Palette")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Pick a base color and a harmony to generate 5 paint colors.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 24)

                // Harmony picker
                harmonySection

                // Color wheel + sliders
                wheelSection

                // Generated palette swatches
                palettePreview

                // Color science info card
                ScienceInfoCard(harmony: harmony)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .onChange(of: hue)        { _, _ in syncToStore() }
        .onChange(of: saturation) { _, _ in syncToStore() }
        .onChange(of: brightness) { _, _ in syncToStore() }
        .onChange(of: harmony)    { _, _ in syncToStore() }
        .onAppear { syncToStore() }
        .sheet(isPresented: $showPresets) {
            PalettePickerView(store: store, onSelect: nil)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Sections

    private var harmonySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color Harmony")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ColorHarmony.allCases) { h in
                        HarmonyChip(harmony: h, isSelected: harmony == h)
                            .onTapGesture { harmony = h }
                    }
                }
                .padding(.horizontal, 24)
            }

            Text(harmony.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 24)
        }
    }

    private var wheelSection: some View {
        VStack(spacing: 20) {
            ColorWheelPicker(hue: $hue, saturation: $saturation)
                .frame(maxWidth: 260)
                .frame(maxWidth: .infinity)

            VStack(spacing: 14) {
                // Brightness
                LabeledSlider(label: "Brightness",
                              value: $brightness, range: 0.2...1.0,
                              tint: Color(hue: hue, saturation: saturation, brightness: brightness),
                              format: { "\(Int($0 * 100))%" })
                // Saturation
                LabeledSlider(label: "Saturation",
                              value: $saturation, range: 0.0...1.0,
                              tint: Color(hue: hue, saturation: saturation, brightness: 0.9),
                              format: { "\(Int($0 * 100))%" })
            }
            .padding(.horizontal, 24)

            // Temperature & hue info row
            HStack(spacing: 16) {
                TemperatureLabel(hue: hue)
                Spacer()
                Text("Hue \(Int(hue * 360))°")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 24)
        }
    }

    private var palettePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Palette")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button("Load Preset") { showPresets = true }
                    .font(.caption.weight(.medium))
                    .tint(.white.opacity(0.55))
            }
            .padding(.horizontal, 24)

            // 5-swatch bar
            HStack(spacing: 0) {
                ForEach(Array(generatedRGBs.enumerated()), id: \.offset) { i, rgb in
                    Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .overlay(alignment: .bottomLeading) {
                            Text("\(i+1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(6)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1)))
            .padding(.horizontal, 24)

            // Individual color values
            HStack(spacing: 0) {
                ForEach(Array(generatedRGBs.enumerated()), id: \.offset) { _, rgb in
                    let hsb = rgbToHSB(rgb)
                    VStack(spacing: 2) {
                        Text("\(Int(hsb.h * 360))°")
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Helpers

    private func syncToStore() {
        let rgbs = generatedRGBs
        let colors = rgbs.enumerated().map { i, rgb in
            PaletteColor(name: "Color \(i+1)", rgb: rgb)
        }
        store.setCustomColors(colors)
    }

    private func rgbToHSB(_ rgb: SIMD3<Float>) -> (h: Double, s: Double, b: Double) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        UIColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 1)
            .getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        return (Double(h), Double(s), Double(b))
    }
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
                // Hue ring
                Circle().fill(AngularGradient(colors: hueColors, center: .center))
                // Saturation fade (white center = zero saturation)
                Circle().fill(RadialGradient(
                    colors: [.white, .clear],
                    center: .center, startRadius: 0, endRadius: radius))
                // Dark rim for contrast
                Circle().stroke(.black.opacity(0.15), lineWidth: 1.5)

                // Cursor
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
// Supporting views
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
    let tint: Color
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
