import SwiftUI

// ---------------------------------------------------------------------------
// GalleryView — grid of saved pour paintings.
// ---------------------------------------------------------------------------
struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var paintings: [PaintingFile] = []
    @State private var fullscreen: PaintingFile?  = nil
    @State private var pendingDelete: PaintingFile? = nil

    var body: some View {
        NavigationStack {
            Group {
                if paintings.isEmpty {
                    emptyState
                } else {
                    paintingGrid
                }
            }
            .navigationTitle("My Art")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { paintings = PaintingStore.loadAll() }
        .fullScreenCover(item: $fullscreen) { PaintingFullscreenView(painting: $0) }
        .confirmationDialog("Delete this painting?",
                            isPresented: Binding(get: { pendingDelete != nil },
                                                 set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let p = pendingDelete { delete(p) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No paintings yet")
                .font(.title3.weight(.semibold))
            Text("Finish your first pour to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var paintingGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2)], spacing: 2) {
                ForEach(paintings) { p in
                    PaintingThumb(painting: p)
                        .onTapGesture       { fullscreen    = p }
                        .onLongPressGesture { pendingDelete = p }
                }
            }
        }
    }

    private func delete(_ p: PaintingFile) {
        try? FileManager.default.removeItem(at: p.url)
        paintings.removeAll { $0.id == p.id }
        pendingDelete = nil
    }
}

// ---------------------------------------------------------------------------
// PaintingThumb — grid cell thumbnail
// ---------------------------------------------------------------------------
private struct PaintingThumb: View {
    let painting: PaintingFile

    var body: some View {
        Group {
            if let img = UIImage(contentsOfFile: painting.url.path) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color(white: 0.15)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(9/16, contentMode: .fill)
        .clipped()
    }
}

// ---------------------------------------------------------------------------
// PaintingFullscreenView — full-screen pinch-zoom viewer
// ---------------------------------------------------------------------------
struct PaintingFullscreenView: View {
    let painting: PaintingFile
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat     = 1
    @State private var baseScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = UIImage(contentsOfFile: painting.url.path) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { v in scale = max(0.5, min(4, baseScale * v)) }
                            .onEnded   { _ in baseScale = scale }
                    )
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                    Spacer()
                    Text(painting.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding()
                }
                Spacer()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// PaintingStore — file-system persistence for finished paintings.
// ---------------------------------------------------------------------------
struct PaintingFile: Identifiable {
    let id:   UUID
    let url:  URL
    let date: Date
}

enum PaintingStore {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("paintings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return }
        let url = directory.appendingPathComponent("painting_\(UUID().uuidString).jpg")
        try? data.write(to: url)
    }

    static func loadAll() -> [PaintingFile] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey]) else { return [] }
        return items
            .filter { $0.pathExtension == "jpg" }
            .compactMap { url in
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
                return PaintingFile(id: UUID(), url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }
}
