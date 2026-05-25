import SwiftUI
import PhotosUI

// ---------------------------------------------------------------------------
// PhotoPickerSheet — SwiftUI wrapper around PHPickerViewController.
// PHPicker runs in a separate sandboxed process and does NOT require Photos
// permission (no usage-description string needed).
// ---------------------------------------------------------------------------
struct PhotoPickerSheet: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter         = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerSheet
        init(_ parent: PhotoPickerSheet) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first,
                  result.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let img = object as? UIImage else { return }
                DispatchQueue.main.async { self.parent.image = img }
            }
        }
    }
}
