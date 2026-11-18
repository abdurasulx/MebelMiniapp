import AVFoundation
import SwiftUI

struct ContentView: View {
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var measurement: FurnitureMeasurement?
    @State private var snapshot: UIImage?
    @State private var isUploading = false
    @State private var uploadMessage: String?
    @State private var resetID = UUID()
    @State private var status = "Kamera ruxsatini tekshiryapmiz…"

    var body: some View {
        Group {
            switch cameraStatus {
            case .authorized:
                scanner
            case .notDetermined:
                ProgressView("Kameraga ruxsat so‘ralmoqda…")
                    .task { await requestCamera() }
            default:
                ContentUnavailableView(
                    "Kamera ruxsati kerak",
                    systemImage: "camera.fill",
                    description: Text("Sozlamalardan Mebel Scanner uchun kamerani yoqing.")
                )
            }
        }
    }

    private var scanner: some View {
        ZStack {
            ARMeasurementView(
                onMeasurement: { measurement = $0 },
                onSnapshot: { snapshot = $0 },
                onTrackingStatus: { status = $0 },
                resetID: resetID
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Mebelning o‘ziga bir marta bosing").font(.headline)
                    Text(status).font(.subheadline).foregroundStyle(.secondary)
                    measurementGrid
                    HStack {
                        Button("Qayta skan", systemImage: "arrow.counterclockwise") { measurement = nil; snapshot = nil; resetID = UUID() }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button(isUploading ? "Yuborilmoqda…" : "3D ga yuborish", systemImage: "arrow.up.circle.fill") { Task { await submitToConverter() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(measurement == nil || snapshot == nil || isUploading)
                    }
                }
                .padding()
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding()
            }
        }
        .accessibilityElement(children: .contain)
        .alert("3D konvertor", isPresented: Binding(get: { uploadMessage != nil }, set: { if !$0 { uploadMessage = nil } })) { Button("OK") {} } message: { Text(uploadMessage ?? "") }
    }

    private var measurementGrid: some View {
        HStack(spacing: 8) {
            measurementCell("Eni", value: measurement?.widthCentimeters)
            measurementCell("Bo‘yi", value: measurement?.heightCentimeters)
            measurementCell("Chuqurligi", value: measurement?.depthCentimeters)
        }
    }

    private func measurementCell(_ title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value?.centimeterText ?? "—")
                .font(.headline.monospacedDigit())
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func submitToConverter() async {
        guard let measurement, let snapshot else { return }
        isUploading = true
        defer { isUploading = false }
        do {
            let id = try await ConverterAPI.submit(image: snapshot, measurement: measurement, collection: "scanner")
            uploadMessage = "3D yaratish navbatiga yuborildi. Job: \(id)"
        } catch {
            uploadMessage = "Yuborib bo‘lmadi. Telefon converter tarmog‘iga ulanganini tekshiring."
        }
    }

    private func requestCamera() async {
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        cameraStatus = allowed ? .authorized : .denied
    }
}

#Preview {
    ContentView()
}
