import SwiftUI

private struct AttendanceCheckInBody: Encodable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let deviceTimestamp: String
    let isMock: Bool
    let integrityToken: String?
    let platform: String

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, accuracy
        case deviceTimestamp = "device_timestamp"
        case isMock = "is_mock"
        case integrityToken = "integrity_token"
        case platform
    }
}

private struct AttendanceResult: Decodable {
    let status: String
    let reason: String
    let action: String

    var isApproved: Bool { status == "approved" }
}

/// Xodim uchun "Ishga keldim"/"Ishni tugatdim" — geolokatsiya orqali
/// backendga yuboriladi, YAKUNIY qarorni backend beradi (docs "Xodimlar ish
/// haqi va davomat tizimi" §13-14). Android'dagi `AttendanceScreen` bilan
/// bir xil oqim.
struct AttendanceView: View {
    private let locationManager = AttendanceLocationManager()
    @State private var isBusy = false
    @State private var result: AttendanceResult?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 12)
            Image(systemName: "clock.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandDeep)

            if isBusy {
                ProgressView()
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            if let result {
                ResultBanner(result: result)
            }

            VStack(spacing: 12) {
                Button {
                    Task { await submit(endpoint: "check_in", action: "check_in") }
                } label: {
                    Label("Ishga keldim", systemImage: "arrow.right.to.line")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandDeep)
                        .foregroundStyle(Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isBusy)

                Button {
                    Task { await submit(endpoint: "check_out", action: "check_out") }
                } label: {
                    Label("Ishni tugatdim", systemImage: "arrow.left.to.line")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandDeep, lineWidth: 1.5))
                        .foregroundStyle(Color.brandDeep)
                }
                .disabled(isBusy)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Davomat")
    }

    private func submit(endpoint: String, action: String) async {
        isBusy = true
        errorMessage = nil
        result = nil
        defer { isBusy = false }
        if JailbreakDetector.isJailbroken {
            errorMessage = "Qurilma xavfsizligi tekshiruvidan o'tmadi"
            return
        }
        do {
            let location = try await locationManager.currentLocation()
            let clientData = "\(location.coordinate.latitude),\(location.coordinate.longitude)".data(using: .utf8) ?? Data()
            let integrityToken = await AppAttestService.currentAssertion(clientData: clientData)
            let body = AttendanceCheckInBody(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
                deviceTimestamp: ISO8601DateFormatter().string(from: location.timestamp),
                isMock: location.isSimulated,
                integrityToken: integrityToken,
                platform: "ios"
            )
            result = try await APIClient.shared.post("/attendance/records/\(endpoint)/", body: body, auth: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ResultBanner: View {
    let result: AttendanceResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.isApproved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.isApproved ? .green : .red)
            Text(bannerText)
                .foregroundStyle(result.isApproved ? .green : .red)
        }
        .padding()
        .background((result.isApproved ? Color.green : Color.red).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var bannerText: String {
        if result.isApproved {
            return result.action == "check_in" ? "Ishga kelish tasdiqlandi" : "Ishni tugatish tasdiqlandi"
        }
        if !result.reason.isEmpty { return result.reason }
        return result.action == "check_in" ? "Ishga kelish tasdiqlanmadi" : "Ishni tugatish tasdiqlanmadi"
    }
}
