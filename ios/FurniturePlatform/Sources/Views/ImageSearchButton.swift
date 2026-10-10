import PhotosUI
import SwiftUI

/// Qidiruv panelidagi kamera tugmasi — bosilganda kamera yoki galereyadan
/// rasm tanlashni so'raydi, tanlangach JPEG `Data` sifatida qaytaradi.
/// `HomeView`da ishlatiladi (endi katalog vazifasini ham shu bajaradi).
struct ImageSearchButton: View {
    @EnvironmentObject private var locale: LocaleStore
    var onImagePicked: (Data) -> Void

    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var showGalleryPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        Button {
            showSourceDialog = true
        } label: {
            Image(systemName: "camera.fill")
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 44, height: 44)
                .background(Color.brandDeep)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .confirmationDialog("Rasm bilan qidirish", isPresented: $showSourceDialog, titleVisibility: .visible) {
            Button(locale.t("home_camera")) { showCamera = true }
            Button(locale.t("home_gallery")) {
                // PhotosPicker o'zi tugma emas, shuning uchun `.photosPicker`
                // modifikatori pastda alohida biriktirilgan — bu yerda faqat
                // uni ko'rsatishga signal beramiz.
                showGalleryPicker = true
            }
            Button(locale.t("profile_delete_account_cancel"), role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { image in
                if let data = image.jpegData(compressionQuality: 0.85) {
                    onImagePicked(data)
                }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showGalleryPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    onImagePicked(data)
                }
                photoPickerItem = nil
            }
        }
    }
}
