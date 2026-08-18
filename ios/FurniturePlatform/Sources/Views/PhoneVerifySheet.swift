import SwiftUI

/// Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
/// foydalanuvchi buyurtma berishga urinsa backend 403 qaytaradi (qarang
/// APIClient.APIError.server statusCode). Shu sheet ochilib, SMS-kod bilan
/// tasdiqlangach `onVerified()` chaqiriladi (chaqiruvchi buyurtmani qayta yuboradi).
struct PhoneVerifySheet: View {
    let initialPhone: String
    let onVerified: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phone: String
    @State private var code = ""
    @State private var codeSent = false
    @State private var debugCode: String?
    @State private var busy = false
    @State private var errorMessage: String?

    init(initialPhone: String, onVerified: @escaping () -> Void) {
        self.initialPhone = initialPhone
        self.onVerified = onVerified
        _phone = State(initialValue: initialPhone)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Buyurtma berishdan oldin telefon raqamingizni SMS-kod bilan tasdiqlashingiz kerak.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if !codeSent {
                    Section {
                        TextField("Telefon (+998…)", text: $phone).keyboardType(.phonePad)
                    }
                } else {
                    Section {
                        if let debugCode {
                            Text("Dev rejim — kod: \(debugCode)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        TextField("SMS-kod", text: $code).keyboardType(.numberPad)
                        Button("Raqamni o'zgartirish") { codeSent = false }
                            .font(.caption)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button(action: codeSent ? confirmCode : requestCode) {
                        if busy {
                            ProgressView()
                        } else {
                            Text(codeSent ? "Tasdiqlash" : "Kod yuborish").bold()
                        }
                    }
                    .disabled(busy || (codeSent ? code.isEmpty : phone.isEmpty))
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.brandDeep)
                    .foregroundStyle(Color.brandPrimary)
                }
            }
            .navigationTitle("Telefonni tasdiqlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
            }
        }
    }

    private func requestCode() {
        busy = true
        errorMessage = nil
        struct Body: Encodable { let phone: String }
        struct Resp: Decodable { let debugCode: String? }
        Task {
            do {
                let resp: Resp = try await APIClient.shared.post(
                    "/users/me/phone/request-otp/", body: Body(phone: phone), auth: true
                )
                debugCode = resp.debugCode
                codeSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
            busy = false
        }
    }

    private func confirmCode() {
        busy = true
        errorMessage = nil
        struct Body: Encodable { let phone: String; let code: String }
        Task {
            do {
                let _: User = try await APIClient.shared.post(
                    "/users/me/phone/verify-otp/", body: Body(phone: phone, code: code), auth: true
                )
                dismiss()
                onVerified()
            } catch {
                errorMessage = error.localizedDescription
            }
            busy = false
        }
    }
}
