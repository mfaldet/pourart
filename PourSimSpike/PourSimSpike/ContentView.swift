import SwiftUI

struct ContentView: View {

    @StateObject private var motion = MotionService()
    @State private var debugMode: UInt32 = 0
    @State private var fps: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            CanvasView(motion: motion, debugMode: $debugMode) { fps in
                self.fps = fps
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // FPS counter (always visible during spike)
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

                Spacer()

                // Debug overlay controls
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
