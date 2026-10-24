import AVFoundation
import SwiftUI

struct ContentView: View {
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var measurement: FurnitureMeasurement?
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
                        Button("Qayta skan", systemImage: "arrow.counterclockwise") { measurement = nil; resetID = UUID() }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Tayyor", systemImage: "checkmark") { }
                            .buttonStyle(.borderedProminent)
                            .disabled(measurement == nil)
                    }
                }
                .padding()
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding()
            }
        }
        .accessibilityElement(children: .contain)
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

    private func requestCamera() async {
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        cameraStatus = allowed ? .authorized : .denied
    }
}

#Preview {
    ContentView()
}
