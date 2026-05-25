import SwiftUI

// ---------------------------------------------------------------------------
// PourFlowView — three-step pre-canvas flow:
//   0 → IntentionView   (technique + vision)
//   1 → PaletteBuilder  (color science)
//   2 → PaintSetup      (modifiers + canvas + base)
//   3 → Canvas          (live sim, replaces this view entirely)
// ---------------------------------------------------------------------------
struct PourFlowView: View {
    @ObservedObject var paletteStore: PaletteStore
    var onDone: () -> Void

    @State private var step:          Int          = 0
    @State private var intention:     String       = ""
    @State private var technique:     PourTechnique = .dirtyPour
    @State private var consistencies: [Float]      = Array(repeating: 0, count: 5)
    @State private var canvasShape:   CanvasShape  = .portrait

    var body: some View {
        if step == 3 {
            CanvasContainerView(
                paletteStore: paletteStore,
                consistency: avgConsistency,
                canvasShape: canvasShape,
                onExit: onDone
            )
        } else {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar + step label
                    VStack(spacing: 10) {
                        FlowProgressBar(current: step, total: 3)
                        HStack {
                            ForEach(0..<3) { i in
                                Text(stepLabel(i))
                                    .font(.system(size: 10, weight: i == step ? .semibold : .regular))
                                    .foregroundStyle(i == step ? .white : .white.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 56)
                    .padding(.bottom, 8)

                    // Step content
                    Group {
                        switch step {
                        case 0:
                            IntentionView(intention: $intention, technique: $technique)
                        case 1:
                            PaletteBuilderView(store: paletteStore)
                        case 2:
                            PaintSetupView(store: paletteStore,
                                           consistencies: $consistencies,
                                           canvasShape: $canvasShape)
                        default:
                            EmptyView()
                        }
                    }
                    .frame(maxHeight: .infinity)

                    // Navigation buttons
                    HStack(spacing: 16) {
                        if step > 0 {
                            Button(action: { step -= 1 }) {
                                Text("Back")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 80)
                                    .padding(.vertical, 14)
                                    .background(.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        Button(action: { step += 1 }) {
                            Text(step == 2 ? "Start Pouring" : "Next")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(step == 2 ? Color.white : Color.white.opacity(0.85))
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var avgConsistency: Float {
        consistencies.isEmpty ? 0 : consistencies.reduce(0, +) / Float(consistencies.count)
    }

    private func stepLabel(_ i: Int) -> String {
        switch i {
        case 0: return "Intention"
        case 1: return "Palette"
        case 2: return "Setup"
        default: return ""
        }
    }
}

// ---------------------------------------------------------------------------
// FlowProgressBar — three-segment capsule progress indicator.
// ---------------------------------------------------------------------------
struct FlowProgressBar: View {
    let current: Int
    let total:   Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.white : Color.white.opacity(0.18))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.25), value: current)
            }
        }
    }
}
