import SwiftUI

// Ocean palette — first preset from the spec. Will move to a palette model
// proper in M3; for now this is enough to validate multi-color + Oklab mixing.
private struct PaletteSwatch: Identifiable {
    let id = UUID()
    let name: String
    let rgb: SIMD3<Float>
    var displayColor: Color {
        Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
    }
}

private let oceanPalette: [PaletteSwatch] = [
    .init(name: "Navy",   rgb: SIMD3(0.05, 0.10, 0.30)),
    .init(name: "Teal",   rgb: SIMD3(0.10, 0.55, 0.55)),
    .init(name: "Sky",    rgb: SIMD3(0.40, 0.72, 0.92)),
    .init(name: "Foam",   rgb: SIMD3(0.95, 0.96, 0.98)),
    .init(name: "Gold",   rgb: SIMD3(0.95, 0.75, 0.30)),
]

struct ContentView: View {

    @StateObject private var motion = MotionService()
    @State private var debugMode: UInt32 = 0
    @State private var fps: Double = 0
    @State private var injectColor: SIMD3<Float> = oceanPalette[0].rgb
    @State private var selectedIndex: Int = 0

    var body: some View {
        ZStack {
            CanvasView(motion: motion,
                       debugMode: $debugMode,
                       injectColor: $injectColor) { fps in
                self.fps = fps
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top: FPS counter + palette swatches
                HStack {
                    Text(String(format: "%.0f fps", fps))
                        .font(.system(.caption, design: .monospaced))
                        .padding(6)
                        .background(.black.opacity(0.5))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 60)

                HStack(spacing: 10) {
                    ForEach(Array(oceanPalette.enumerated()), id: \.element.id) { idx, swatch in
                        Button {
                            selectedIndex = idx
                            injectColor = swatch.rgb
                        } label: {
                            Circle()
                                .fill(swatch.displayColor)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: selectedIndex == idx ? 3 : 1)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 2)
                        }
                    }
                }
                .padding(.top, 12)

                Spacer()

                // Bottom: debug overlay toggles
                HStack(spacing: 8) {
                    debugButton("Off",      mode: 0)
                    debugButton("Velocity", mode: 1)
                    debugButton("Pressure", mode: 2)
                    debugButton("Density",  mode: 3)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 40)
            }
        }
        .onDisappear { motion.stop() }
    }

    private func debugButton(_ label: String, mode: UInt32) -> some View {
        Button(label) { debugMode = mode }
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(debugMode == mode ? Color.accentColor : .black.opacity(0.5))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
