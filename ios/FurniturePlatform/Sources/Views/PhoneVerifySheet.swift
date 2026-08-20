import SwiftUI

/// Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
/// foydalanuvchi buyurtma berishga urinsa backend 403 qaytaradi (qarang
/// APIError.server statusCode). Shu sheet ochilib, SMS-kod bilan
/// tasdiqlangach `onVerified()` chaqiriladi (chaqiruvchi buyurtmani qayta yuboradi).
///
/// OTP orqali kirish ekrani (AccountView.swift'dagi AuthFormView) bilan
/// bir xil naqsh: davlat tanlagich + kod prefiksli/uzunlik-cheklangan
/// raqam maydoni, N-katakli SMS-kod kiritish (OtpBoxInput), qayta
/// yuborish countdown'i.
struct PhoneVerifySheet: View {
    let initialPhone: String
    let onVerified: () -> Void

    private static let otpLength = 6

    @Environment(\.dismiss) private var dismiss
    @State private var country = cisCountries[0]
    @State private var showCountryPicker = false
    @State private var phone: String
    @State private var code = ""
    @State private var codeSent = false
    @State private var debugCode: String?
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var resendSeconds = 0
    @State private var resendTimer: Timer?

    init(initialPhone: String, onVerified: @escaping () -> Void) {
        self.initialPhone = initialPhone
        self.onVerified = onVerified
        // Backend'dan qaytgan `phone` odatda davlat kodi bilan birga keladi
        // (masalan "+998901234567") — shuni mos davlat/mahalliy raqamga
        // ajratamiz, aks holda oddiy mahalliy raqam sifatida qoldiramiz.
        var country = cisCountries[0]
        var localNumber = initialPhone
        for c in cisCountries where initialPhone.hasPrefix(c.dialCode) {
            country = c
            localNumber = String(initialPhone.dropFirst(c.dialCode.count))
            break
        }
        _country = State(initialValue: country)
        _phone = State(initialValue: localNumber)
    }

    private var phoneValid: Bool { country.isValid(phone) }
    private var fullPhone: String { "\(country.dialCode)\(phone)" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Buyurtma berishdan oldin telefon raqamingizni SMS-kod bilan tasdiqlashingiz kerak.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if !codeSent {
                    Section {
                        Button {
                            showCountryPicker = true
                        } label: {
                            HStack {
                                Text("\(country.flag) \(country.name) (\(country.dialCode))")
                                Spacer()
                                Image(systemName: "chevron.down").font(.caption)
                            }
                        }
                        .foregroundStyle(.primary)

                        HStack {
                            Text(country.dialCode).foregroundStyle(.secondary)
                            TextField("Telefon", text: $phone)
                                .keyboardType(.numberPad)
                                .onChange(of: phone) { _, newValue in
                                    let digits = newValue.filter(\.isNumber)
                                    phone = String(digits.prefix(country.phoneLength))
                                }
                        }
                        if !phone.isEmpty && !phoneValid {
                            Text("Telefon raqami noto'g'ri").font(.caption).foregroundStyle(.red)
                        }
                    }
                } else {
                    Section {
                        if let debugCode {
                            Text("Dev rejim — kod: \(debugCode)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        OtpBoxInput(code: $code, length: Self.otpLength) { code in
                            if !busy { confirmCode(code) }
                        }
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 6)
                        if busy {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    }
                    Section {
                        Button {
                            if resendSeconds == 0 { requestCode() }
                        } label: {
                            Text(resendSeconds > 0 ? "Qayta yuborish (\(resendSeconds)s)" : "Qayta yuborish")
                        }
                        .disabled(resendSeconds > 0 || busy)
                        Button("Raqamni o'zgartirish") { codeSent = false }
                            .font(.caption)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                if !codeSent {
                    Section {
                        Button(action: requestCode) {
                            if busy {
                                ProgressView()
                            } else {
                                Text("Kod yuborish").bold()
                            }
                        }
                        .disabled(busy || !phoneValid)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.brandDeep)
                        .foregroundStyle(Color.brandPrimary)
                    }
                }
            }
            .confirmationDialog("Davlatni tanlang", isPresented: $showCountryPicker) {
                ForEach(cisCountries) { c in
                    Button("\(c.flag) \(c.name) (\(c.dialCode))") {
                        country = c
                        if phone.count > c.phoneLength { phone = String(phone.prefix(c.phoneLength)) }
                    }
                }
            }
            .navigationTitle("Telefonni tasdiqlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
            }
            .onDisappear { resendTimer?.invalidate() }
        }
    }

    private func startCountdown(_ seconds: Int) {
        resendTimer?.invalidate()
        resendSeconds = seconds
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if resendSeconds <= 1 {
                    resendTimer?.invalidate()
                    resendSeconds = 0
                } else {
                    resendSeconds -= 1
                }
            }
        }
    }

    private func requestCode() {
        busy = true
        errorMessage = nil
        struct Body: Encodable { let phone: String }
        struct Resp: Decodable { let debugCode: String?; let resendAfter: Int? }
        Task {
            do {
                let resp: Resp = try await APIClient.shared.post(
                    "/users/me/phone/request-otp/", body: Body(phone: fullPhone), auth: true
                )
                debugCode = resp.debugCode
                code = ""
                codeSent = true
                startCountdown(resp.resendAfter ?? 60)
            } catch {
                errorMessage = error.localizedDescription
            }
            busy = false
        }
    }

    private func confirmCode(_ code: String) {
        busy = true
        errorMessage = nil
        struct Body: Encodable { let phone: String; let code: String }
        Task {
            do {
                let _: User = try await APIClient.shared.post(
                    "/users/me/phone/verify-otp/", body: Body(phone: fullPhone, code: code), auth: true
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
