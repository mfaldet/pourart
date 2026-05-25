import SwiftUI
import Photos

// ---------------------------------------------------------------------------
// PreviewView — frame/wall composite, save, share
// ---------------------------------------------------------------------------
struct PreviewView: View {

    let image: UIImage
    var onBackToCanvas: () -> Void
    var onDone: () -> Void

    @State private var selectedFrame: FrameStyle = .minimal
    @State private var selectedWall:  WallColor  = .cream
    @State private var scale: CGFloat            = 1.0
    @State private var baseScale: CGFloat        = 1.0
    @State private var saveAlert: SaveAlert?     = nil
    @State private var showShareSheet            = false
    @State private var compositeForShare: UIImage? = nil

    var body: some View {
        ZStack {
            // Wall color fill
            selectedWall.color.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top buttons
                HStack {
                    Button(action: onBackToCanvas) {
                        Label("Canvas", systemImage: "chevron.left")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Button("Done", action: onDone)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 16)

                // Painting with frame — pinch-to-zoom
                GeometryReader { geo in
                    let size = min(geo.size.width, geo.size.height) * 0.85
                    ZStack {
                        framedPainting(size: size)
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { v in scale = max(0.5, min(3.0, baseScale * v)) }
                                    .onEnded   { _ in baseScale = scale }
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer(minLength: 0)

                // Controls
                VStack(spacing: 16) {
                    // Frame picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Frame")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(FrameStyle.allCases) { style in
                                    FrameChip(style: style, isSelected: selectedFrame == style)
                                        .onTapGesture { selectedFrame = style }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Wall color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wall")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(WallColor.allCases) { wall in
                                    Circle()
                                        .fill(wall.color)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle().stroke(
                                                selectedWall == wall ? Color.primary : Color.clear,
                                                lineWidth: 2.5)
                                        )
                                        .onTapGesture { selectedWall = wall }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Save / Share
                    HStack(spacing: 14) {
                        Button {
                            saveToPhotos()
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.primary)
                                .foregroundStyle(Color(uiColor: .systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            compositeForShare = renderComposite()
                            showShareSheet    = compositeForShare != nil
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.primary.opacity(0.12))
                                .foregroundStyle(Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert(item: $saveAlert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = compositeForShare {
                ShareSheet(items: [img])
            }
        }
    }

    // Painting image with the chosen frame overlay
    @ViewBuilder
    private func framedPainting(size: CGFloat) -> some View {
        let aspect = image.size.height / max(image.size.width, 1)
        let w = size
        let h = size * aspect

        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: w, height: h)
            .overlay(selectedFrame.overlay(width: w, height: h))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }

    // Render painting + frame to a UIImage for save/share
    private func renderComposite() -> UIImage? {
        let aspect = image.size.height / max(image.size.width, 1)
        let w: CGFloat = 1080
        let h: CGFloat = w * aspect

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
            selectedFrame.draw(in: CGRect(x: 0, y: 0, width: w, height: h), context: ctx.cgContext)
        }
    }

    private func saveToPhotos() {
        guard let composite = renderComposite() else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(composite, nil, nil, nil)
                    saveAlert = SaveAlert(title: "Saved!", message: "Your painting was added to Photos.")
                } else {
                    saveAlert = SaveAlert(title: "Permission Denied",
                                         message: "Allow Photos access in Settings to save your painting.")
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Frame styles
// ---------------------------------------------------------------------------
enum FrameStyle: String, CaseIterable, Identifiable {
    case minimal, white, black, gold, wood
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    @ViewBuilder
    func overlay(width: CGFloat, height: CGFloat) -> some View {
        switch self {
        case .minimal:
            EmptyView()
        case .white:
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white, lineWidth: 16)
        case .black:
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black, lineWidth: 16)
        case .gold:
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    LinearGradient(colors: [Color(hue: 0.12, saturation: 0.9, brightness: 0.85),
                                            Color(hue: 0.11, saturation: 0.6, brightness: 0.65),
                                            Color(hue: 0.12, saturation: 0.9, brightness: 0.85)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 16)
        case .wood:
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    LinearGradient(colors: [Color(red: 0.55, green: 0.35, blue: 0.18),
                                            Color(red: 0.38, green: 0.22, blue: 0.10),
                                            Color(red: 0.55, green: 0.35, blue: 0.18)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 16)
        }
    }

    func draw(in rect: CGRect, context: CGContext) {
        let inset: CGFloat = 0
        let r = rect.insetBy(dx: inset, dy: inset)
        switch self {
        case .minimal:
            break
        case .white:
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(32)
            context.stroke(r)
        case .black:
            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(32)
            context.stroke(r)
        case .gold:
            context.setStrokeColor(UIColor(hue: 0.12, saturation: 0.8, brightness: 0.8, alpha: 1).cgColor)
            context.setLineWidth(32)
            context.stroke(r)
        case .wood:
            context.setStrokeColor(UIColor(red: 0.47, green: 0.29, blue: 0.14, alpha: 1).cgColor)
            context.setLineWidth(32)
            context.stroke(r)
        }
    }
}

// ---------------------------------------------------------------------------
// Wall colors
// ---------------------------------------------------------------------------
enum WallColor: String, CaseIterable, Identifiable {
    case cream, charcoal, sage, navy, blush
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .cream:    return Color(red: 0.97, green: 0.95, blue: 0.90)
        case .charcoal: return Color(red: 0.20, green: 0.20, blue: 0.22)
        case .sage:     return Color(red: 0.72, green: 0.78, blue: 0.70)
        case .navy:     return Color(red: 0.10, green: 0.15, blue: 0.30)
        case .blush:    return Color(red: 0.95, green: 0.82, blue: 0.80)
        }
    }
}

// ---------------------------------------------------------------------------
// FrameChip — label pill for frame selection
// ---------------------------------------------------------------------------
private struct FrameChip: View {
    let style: FrameStyle
    let isSelected: Bool

    var body: some View {
        Text(style.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary : Color.primary.opacity(0.1))
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Color.primary)
            .clipShape(Capsule())
    }
}

// ---------------------------------------------------------------------------
// ShareSheet — UIActivityViewController bridge
// ---------------------------------------------------------------------------
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// ---------------------------------------------------------------------------
// Alert model — Identifiable so .alert(item:) works
// ---------------------------------------------------------------------------
private struct SaveAlert: Identifiable {
    let id   = UUID()
    let title: String
    let message: String
}
