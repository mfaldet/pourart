import SwiftUI

// ---------------------------------------------------------------------------
// IntentionView — Step 0: pick a technique, describe your vision.
// ---------------------------------------------------------------------------
struct IntentionView: View {
    @Binding var intention:  String
    @Binding var technique:  PourTechnique

    @State private var showSuggestion = false
    @State private var suggestionText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                header

                intentionField

                if showSuggestion {
                    suggestionBubble
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                techniqueGrid

                selectedDetail
            }
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.25), value: showSuggestion)
        .animation(.easeInOut(duration: 0.2),  value: technique)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What's Your Vision?")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Choose a technique and describe what you want to create.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 24)
    }

    private var intentionField: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextField("e.g. Pastel flowers on a black background…",
                      text: $intention, axis: .vertical)
                .lineLimit(3...)
                .padding(14)
                .background(.white.opacity(0.08))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.14), lineWidth: 1))
                .padding(.horizontal, 24)

            Button {
                suggestionText = generateSuggestion()
                withAnimation { showSuggestion = true }
            } label: {
                Label("Inspire Me", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
            }
            .tint(.yellow)
            .padding(.trailing, 24)
        }
    }

    private var suggestionBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Suggestions", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
            Text(suggestionText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(16)
        .background(.yellow.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(.yellow.opacity(0.22), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private var techniqueGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technique")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 10) {
                ForEach(PourTechnique.allCases) { t in
                    TechniqueCard(technique: t, isSelected: technique == t)
                        .onTapGesture { technique = t }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var selectedDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(technique.displayName)
                .font(.headline)
                .foregroundStyle(.white)

            Text(technique.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 6) {
                Label(technique.consistencyTip, systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan.opacity(0.9))
                Label(technique.colorsTip, systemImage: "paintpalette")
                    .font(.caption)
                    .foregroundStyle(.purple.opacity(0.9))
            }
            .padding(12)
            .background(.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }

    // MARK: - AI suggestion (static; hook real Claude API call here)
    private func generateSuggestion() -> String {
        let text = intention.lowercased()
        if text.contains("flower") || text.contains("floral") || text.contains("petal") {
            return "Soft analogous colors — blush, sage, and lavender — work beautifully for florals. Use a thin consistency so paint spreads into petal-like shapes. Ring Pour or Bloom will create natural floral spreads."
        }
        if text.contains("ocean") || text.contains("water") || text.contains("sea") || text.contains("wave") {
            return "Navy, teal, seafoam, and gold. Try Dutch Pour with a straw for wave-like froth at every boundary. Thin base + medium accent colors."
        }
        if text.contains("galaxy") || text.contains("space") || text.contains("cosmic") || text.contains("nebula") {
            return "Deep purples, midnight blue, black, and silver. Flip Cup or Dirty Pour with a metallic accent and medium-thick consistency for defined cells."
        }
        if text.contains("sunset") || text.contains("sunrise") || text.contains("sky") {
            return "Red, orange, yellow — with a touch of purple at the edge. Tree Ring poured slowly from the same spot creates gorgeous horizon layers."
        }
        if text.contains("pastel") || text.contains("soft") || text.contains("dreamy") {
            return "Keep brightness high (> 80%) and saturation low (< 50%) across all colors. Analogous harmony stays cohesive. Use slightly thick consistency so pastels don't over-blend into grey."
        }
        if text.contains("bold") || text.contains("vibrant") || text.contains("bright") || text.contains("neon") {
            return "Full saturation, complementary or triadic harmony. Dirty Pour or Swipe lets each color fight for dominance. Don't be afraid of contrast — it drives the energy."
        }
        // Fallback: technique-based suggestion
        return "For \(technique.displayName) — \(technique.consistencyTip) \(technique.colorsTip) Start with your darkest color at the bottom of the pour cup so it flows out last and sits on top."
    }
}

// ---------------------------------------------------------------------------
// TechniqueCard — gradient card with icon, used in the technique picker grid.
// ---------------------------------------------------------------------------
struct TechniqueCard: View {
    let technique:  PourTechnique
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: technique.gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing))
                    .frame(height: 68)
                Image(systemName: technique.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 2)
            }
            Text(technique.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(10)
        .background(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1.5))
    }
}
