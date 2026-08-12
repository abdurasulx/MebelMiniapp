import SwiftUI
import UIKit

/// Kamera orqali rasmga olish (bosh sahifa/katalogdagi "rasm bilan qidirish"
/// uchun) — `PhotosPicker` faqat galereyani qamrab oladi, kamera uchun hali
/// ham `UIImagePickerController` kerak.
struct CameraImagePicker: UIViewControllerRepresentable {
    var onPicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage) -> Void
        init(onPicked: @escaping (UIImage) -> Void) { self.onPicked = onPicked }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onPicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
