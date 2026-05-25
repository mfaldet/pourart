import SwiftUI
import simd

// ---------------------------------------------------------------------------
// PaintSetupView — Step 2: paint consistency, canvas shape, base color.
// ---------------------------------------------------------------------------
struct PaintSetupView: View {
    @ObservedObject var store: PaletteStore
    @Binding var consistencies: [Float]
    @Binding var canvasShape:   CanvasShape

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {

                header

                canvasShapeSection

                baseColorSection

                consistencySection
            }
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prepare Your Paint")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Mix your paint and choose your canvas before you start.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 24)
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Paint Consistency")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("In real pour painting each color is thinned or thickened separately with pouring medium. Adjust the mix for each color below.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 24)

            ForEach(Array(store.activePalette.colors.enumerated()), id: \.element.id) { i, color in
                ConsistencyRow(color: color, value: consistencyBinding(for: i))
                    .padding(.horizontal, 24)
            }

            // Global consistency summary
            GlobalConsistencyBadge(avgConsistency: avgConsistency)
                .padding(.horizontal, 24)
        }
    }

    private var canvasShapeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Canvas Shape")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Sets your artistic intent. The actual device screen stays portrait.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 24)

            HStack(spacing: 10) {
                ForEach(CanvasShape.allCases) { shape in
                    CanvasShapeButton(shape: shape, isSelected: canvasShape == shape)
                        .onTapGesture { canvasShape = shape }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var baseColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Base Color")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("A wet base coat helps paint flow and defines the background. White is the classic choice.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 24)

            HStack(spacing: 14) {
                ForEach(PaletteStore.basePresets, id: \.name) { preset in
                    let selected = distance(store.baseColor, preset.rgb) < 0.01
                    VStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: Double(preset.rgb.x),
                                        green: Double(preset.rgb.y),
                                        blue: Double(preset.rgb.z)))
                            .frame(width: 46, height: 46)
                            .overlay(Circle().stroke(
                                selected ? Color.white : Color.white.opacity(0.2),
                                lineWidth: selected ? 2.5 : 1))
                        Text(preset.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .onTapGesture { store.setBaseColor(preset.rgb) }
                }
                VStack(spacing: 5) {
                    BaseColorPickerButton(store: store)
                        .frame(width: 46, height: 46)
                    Text("Custom")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Helpers

    private var avgConsistency: Float {
        guard !consistencies.isEmpty else { return 0 }
        return consistencies.reduce(0, +) / Float(consistencies.count)
    }

    private func consistencyBinding(for index: Int) -> Binding<Float> {
        Binding(
            get: { index < consistencies.count ? consistencies[index] : 0 },
            set: { if index < consistencies.count { consistencies[index] = $0 } }
        )
    }
}

// ---------------------------------------------------------------------------
// ConsistencyRow — one color's thin ↔ thick slider.
// ---------------------------------------------------------------------------
struct ConsistencyRow: View {
    let color: PaletteColor
    @Binding var value: Float

    private var label: String {
        switch value {
        case ..<(-0.55): return "Very Thin"
        case ..<(-0.15): return "Thin"
        case ..<0.15:    return "Medium"
        case ..<0.55:    return "Thick"
        default:         return "Very Thick"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.displayColor)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(color.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                HStack(spacing: 6) {
                    Text("Thin")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.35))
                    Slider(value: $value, in: -1...1)
                        .tint(color.displayColor)
                    Text("Thick")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// ---------------------------------------------------------------------------
// GlobalConsistencyBadge — shows the averaged mix setting.
// ---------------------------------------------------------------------------
struct GlobalConsistencyBadge: View {
    let avgConsistency: Float

    private var summary: String {
        switch avgConsistency {
        case ..<(-0.4): return "Very Thin — paint will spread fast and far."
        case ..<(-0.1): return "Thin — good flow, soft cell edges."
        case ..<0.1:    return "Medium — balanced flow and cell definition."
        case ..<0.4:    return "Thick — slow spread, bold cell edges."
        default:        return "Very Thick — paint will pile and resist spreading."
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .foregroundStyle(.blue)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(10)
        .background(.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// ---------------------------------------------------------------------------
// CanvasShapeButton — shape selector button.
// ---------------------------------------------------------------------------
struct CanvasShapeButton: View {
    let shape:      CanvasShape
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: shape.icon)
                .font(.title2)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
            Text(shape.displayName)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isSelected ? .white.opacity(0.15) : .white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5))
    }
}
