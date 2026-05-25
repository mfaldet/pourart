import SwiftUI
import simd

// ---------------------------------------------------------------------------
// PaletteSlotEditor — full per-slot editor with HSB sliders, hex input,
// variant pickers (tints/shades/tones), and a live preview.
// ---------------------------------------------------------------------------
struct PaletteSlotEditor: View {
    @Binding var rgb: SIMD3<Float>
    @Environment(\.dismiss) private var dismiss

    @State private var hue:        Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0
    @State private var hexInput:   String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    livePreview

                    hexField

                    hsbSliders

                    variantSection("Tints (lighter)",
                                  variants: ColorTools.tints(of: rgb, count: 7))
                    variantSection("Shades (darker)",
                                  variants: ColorTools.shades(of: rgb, count: 7))
                    variantSection("Tones (muted)",
                                  variants: ColorTools.tones(of: rgb, count: 7))

                    colorInfo

                    colorBlindnessGrid
                }
                .padding(20)
            }
            .navigationTitle("Edit Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { syncFromRGB() }
        .onChange(of: hue)        { _, _ in syncToRGB() }
        .onChange(of: saturation) { _, _ in syncToRGB() }
        .onChange(of: brightness) { _, _ in syncToRGB() }
    }

    // MARK: - Sections

    private var livePreview: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z)))
                .frame(height: 120)
                .overlay(
                    Text(ColorTools.hex(rgb))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(ColorTools.legibleForeground(rgb))
                )
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

            Text("Hue \(Int(hue * 360))°  ·  Sat \(Int(saturation * 100))%  ·  Bri \(Int(brightness * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var hexField: some View {
        HStack {
            Text("Hex")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            TextField("#RRGGBB", text: $hexInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .background(.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { applyHexInput() }

            Button("Apply") { applyHexInput() }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.1))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var hsbSliders: some View {
        VStack(spacing: 12) {
            // Hue: gradient slider with rainbow track
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(hue * 360))°")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                GradientSlider(value: $hue, in: 0...1,
                               gradient: hueGradient,
                               trackHeight: 14)
            }

            // Saturation
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Saturation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(saturation * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                GradientSlider(value: $saturation, in: 0...1,
                               gradient: Gradient(colors: [
                                   Color(hue: hue, saturation: 0,  brightness: brightness),
                                   Color(hue: hue, saturation: 1,  brightness: brightness)]),
                               trackHeight: 14)
            }

            // Brightness
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Brightness")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(brightness * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                GradientSlider(value: $brightness, in: 0...1,
                               gradient: Gradient(colors: [
                                   .black,
                                   Color(hue: hue, saturation: saturation, brightness: 1)]),
                               trackHeight: 14)
            }
        }
    }

    private func variantSection(_ title: String, variants: [SIMD3<Float>]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(Array(variants.enumerated()), id: \.offset) { _, v in
                    Color(red: Double(v.x), green: Double(v.y), blue: Double(v.z))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .onTapGesture {
                            rgb = v
                            syncFromRGB()
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1)))
        }
    }

    // MARK: - Color info / accessibility

    private var colorInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Details")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                infoTile("RGB", "\(Int(rgb.x*255)), \(Int(rgb.y*255)), \(Int(rgb.z*255))")
                infoTile("HSB", "\(Int(hue*360))° \(Int(saturation*100))% \(Int(brightness*100))%")
            }
            HStack {
                infoTile("Hex", ColorTools.hex(rgb))
                infoTile("Luma",
                         String(format: "%.0f%%", ColorTools.luminance(rgb) * 100))
            }
        }
    }

    private func infoTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var colorBlindnessGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How others see this color")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                colorBlindnessChip(label: "Normal",  rgb: rgb)
                ForEach(ColorBlindness.allCases) { type in
                    colorBlindnessChip(label: type.label,
                                       rgb: ColorTools.simulate(rgb, type: type))
                }
            }
        }
    }

    private func colorBlindnessChip(label: String, rgb: SIMD3<Float>) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z)))
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.1)))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var hueGradient: Gradient {
        Gradient(colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
            Color(hue: $0, saturation: 1, brightness: 1)
        })
    }

    private func syncFromRGB() {
        let (h, s, b) = ColorTools.hsb(from: rgb)
        hue        = h
        saturation = s
        brightness = b
        hexInput   = ColorTools.hex(rgb)
    }

    private func syncToRGB() {
        let new = ColorTools.rgb(h: hue, s: saturation, b: brightness)
        if distance(new, rgb) > 0.001 {
            rgb = new
            hexInput = ColorTools.hex(rgb)
        }
    }

    private func applyHexInput() {
        if let parsed = ColorTools.rgb(fromHex: hexInput) {
            rgb = parsed
            syncFromRGB()
        }
    }
}

// ---------------------------------------------------------------------------
// GradientSlider — custom slider with a gradient track and a draggable thumb.
// ---------------------------------------------------------------------------
struct GradientSlider: View {
    @Binding var value:   Double
    let range:            ClosedRange<Double>
    let gradient:         Gradient
    var trackHeight:      CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(LinearGradient(gradient: gradient,
                                         startPoint: .leading,
                                         endPoint: .trailing))
                    .frame(height: trackHeight)

                Circle()
                    .fill(.white)
                    .frame(width: trackHeight + 8, height: trackHeight + 8)
                    .overlay(Circle().stroke(.black.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(x: thumbOffset(in: width))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let raw = max(0, min(1, v.location.x / width))
                value = range.lowerBound + raw * (range.upperBound - range.lowerBound)
            })
        }
        .frame(height: trackHeight + 12)
    }

    private func thumbOffset(in width: CGFloat) -> CGFloat {
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(normalized) * width - (trackHeight + 8) / 2
    }
}
