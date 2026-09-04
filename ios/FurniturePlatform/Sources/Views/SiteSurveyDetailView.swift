import SwiftUI

private struct SurveyUpdateBody: Encodable {
    let notes: String
    let latitude: Double?
    let longitude: Double?
    let status: String
}

/// Bitta "joy o'rganish" tafsiloti — usta shu yerda rasm/video yuklaydi,
/// izoh/geolokatsiya kiritadi va tashrifdan so'ng CUSTOM_PROJECT
/// buyurtmasini yaratadi (qarang backend apps.custom_orders).
struct SiteSurveyDetailView: View {
    let surveyId: String
    var onChanged: (() -> Void)? = nil

    @State private var survey: SiteSurvey?
    @State private var notes = ""
    @State private var isLoading = true
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showVideoCamera = false
    @State private var showCreateOrder = false
    private let locationManager = AttendanceLocationManager()

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let survey {
                Form {
                    Section {
                        Text(survey.address.isEmpty ? "Manzil ko'rsatilmagan" : survey.address).bold()
                        Text("Mijoz: \(survey.customerName ?? "—") · Holat: \(survey.statusDisplay)")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section("Izoh") {
                        TextEditor(text: $notes).frame(minHeight: 100)
                        Button {
                            Task { await saveNotesAndLocation() }
                        } label: {
                            Label("Izoh va joylashuvni saqlash", systemImage: "square.and.arrow.down")
                        }
                        .disabled(isBusy)
                    }

                    Section("Rasm/video") {
                        HStack {
                            Button { showCamera = true } label: {
                                Label("Rasm", systemImage: "camera")
                            }
                            Spacer()
                            Button { showVideoCamera = true } label: {
                                Label("Video", systemImage: "video")
                            }
                        }
                        ForEach(survey.media) { m in
                            Label(m.mediaType == "video" ? "Video" : "Rasm", systemImage: m.mediaType == "video" ? "video" : "photo")
                        }
                    }

                    if survey.order == nil {
                        Button {
                            showCreateOrder = true
                        } label: {
                            Label("Buyurtma yaratish", systemImage: "cart.badge.plus")
                        }
                    } else {
                        Text("Bu joy uchun buyurtma allaqachon yaratilgan.").foregroundStyle(.green)
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Joy o'rganish")
        .task { await load() }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { image in
                showCamera = false
                if let data = image.jpegData(compressionQuality: 0.8) {
                    Task { await uploadMedia(data: data, isVideo: false) }
                }
            }
        }
        .fullScreenCover(isPresented: $showVideoCamera) {
            CameraVideoPicker { url in
                showVideoCamera = false
                if let data = try? Data(contentsOf: url) {
                    Task { await uploadMedia(data: data, isVideo: true) }
                }
            }
        }
        .sheet(isPresented: $showCreateOrder, onDismiss: { Task { await load() } }) {
            if let survey {
                NavigationStack {
                    CreateCustomOrderView(survey: survey)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let s: SiteSurvey = try await APIClient.shared.get("/site-surveys/\(surveyId)/", auth: true)
            survey = s
            notes = s.notes
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func saveNotesAndLocation() async {
        isBusy = true
        defer { isBusy = false }
        var lat: Double?
        var lng: Double?
        if let location = try? await locationManager.currentLocation() {
            lat = location.coordinate.latitude
            lng = location.coordinate.longitude
        }
        do {
            let _: SiteSurvey = try await APIClient.shared.patch(
                "/site-surveys/\(surveyId)/",
                body: SurveyUpdateBody(notes: notes, latitude: lat, longitude: lng, status: "visited"),
                auth: true
            )
            await load()
            onChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadMedia(data: Data, isVideo: Bool) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let _: SiteSurveyMedia = try await APIClient.shared.postMultipartImage(
                "/site-surveys/\(surveyId)/media/",
                imageData: data,
                imageFieldName: "file",
                fileName: isVideo ? "video.mov" : "photo.jpg",
                mimeType: isVideo ? "video/quicktime" : "image/jpeg",
                fields: ["media_type": isVideo ? "video" : "photo"],
                auth: true
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
