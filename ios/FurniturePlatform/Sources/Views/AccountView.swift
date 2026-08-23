import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            Group {
                // `isNewUser` true bo'lsa, tokenlar allaqachon olingan bo'lsa ham
                // `AuthFormView` ko'rsatishda davom etadi — u ism/familiya
                // so'raydigan profil bosqichini ko'rsatishi kerak (aks holda
                // `auth.user` mavjud bo'lishi bilanoq ProfileView'ga o'tib,
                // bu bosqich hech qachon ko'rinmay qoladi).
                if let user = auth.user, !auth.isNewUser {
                    ProfileView(user: user)
                } else {
                    AuthFormView()
                }
            }
            .navigationTitle("Profil")
            .toolbar {
                if auth.user != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NotificationBellButton()
                    }
                }
            }
        }
    }
}

private struct ProfileView: View {
    let user: User
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var locale: LocaleStore
    @State private var orders: [OrderSummary] = []
    @State private var invitations: [EmployeeInvitation] = []
    @State private var career: [CareerEntry] = []
    @State private var isLoading = false
    @State private var busyInvitationId: String?
    @State private var showLanguagePicker = false
    @State private var showRolePicker = false
    @State private var showPhoneVerify = false
    // Google/Telegram bog'lash tugmalari alohida-alohida holat kuzatadi —
    // bitta umumiy flag bo'lsa, Google bosilganda Telegram tugmasi ham
    // (aslida bosilmagan bo'lsa-da) spinner ko'rsatib qolishi mumkin edi
    // (xuddi shu xato oldin login tugmalarida bo'lgan — qarang AuthFormView).
    @State private var linkingGoogle = false
    @State private var linkingTelegram = false

    var body: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(Color.brandPrimary)
                        .frame(width: 48, height: 48)
                        .overlay(Text(String((user.firstName?.first ?? user.email.first) ?? "?")).bold().foregroundColor(.brandDeep))
                    VStack(alignment: .leading) {
                        Text(user.firstName?.isEmpty == false ? user.firstName! : user.email).bold()
                        Text(user.email).font(.caption).foregroundStyle(.secondary)
                        if let workerId = user.workerId {
                            HStack(spacing: 4) {
                                Text("ID: \(workerId)").font(.caption).foregroundStyle(.secondary)
                                Button {
                                    UIPasteboard.general.string = workerId
                                } label: {
                                    Image(systemName: "doc.on.doc").font(.caption2)
                                }
                            }
                        }
                    }
                }
            }

            Section("Tasdiqlash holati") {
                HStack {
                    Image(systemName: (user.phoneVerified ?? true) ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle((user.phoneVerified ?? true) ? .green : .orange)
                    Text((user.phoneVerified ?? true) ? "Tasdiqlangan profil" : "Tasdiqlanmagan profil")
                    Spacer()
                    if !(user.phoneVerified ?? true) {
                        Button("Tasdiqlash") { showPhoneVerify = true }.font(.caption)
                    }
                }
                if !(user.phoneVerified ?? true) {
                    Text("Tasdiqlanmagan profil bilan buyurtma bera olmaysiz.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showPhoneVerify) {
                PhoneVerifySheet(initialPhone: user.phone ?? "") {
                    Task { await auth.refreshUser() }
                }
            }

            Section("Bog'langan hisoblar") {
                HStack {
                    Image("google_logo").resizable().scaledToFit().frame(width: 20, height: 20)
                    Text("Google")
                    Spacer()
                    if user.hasGoogle ?? false {
                        Label("Bog'langan", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption).foregroundStyle(.green)
                    } else if linkingGoogle {
                        ProgressView()
                    } else {
                        Button("Bog'lash") {
                            linkingGoogle = true
                            Task {
                                await auth.linkGoogle()
                                linkingGoogle = false
                            }
                        }
                        .font(.caption)
                    }
                }
                HStack {
                    Image("telegram_logo").resizable().scaledToFit().frame(width: 20, height: 20)
                    Text("Telegram")
                    Spacer()
                    if user.hasTelegram ?? false {
                        Label("Bog'langan", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption).foregroundStyle(.green)
                    } else if linkingTelegram {
                        ProgressView()
                    } else {
                        Button("Bog'lash") {
                            linkingTelegram = true
                            Task {
                                await auth.linkTelegram()
                                linkingTelegram = false
                            }
                        }
                        .font(.caption)
                    }
                }
                if let error = auth.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    showLanguagePicker = true
                } label: {
                    HStack {
                        Label(locale.t("profile_language"), systemImage: "globe")
                        Spacer()
                        Text({
                            let current = appLocales.first { $0.code == locale.code }
                            return current.map { "\($0.flag) \($0.nativeName)" } ?? ""
                        }())
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .confirmationDialog(locale.t("profile_language"), isPresented: $showLanguagePicker) {
                ForEach(appLocales, id: \.code) { l in
                    Button("\(l.flag) \(l.nativeName)") { locale.setLocale(l.code) }
                }
            }

            // Faqat hozir kasbi bor xodimda ko'rinadi. Ikkinchi tugma matni —
            // bitta kasbi bo'lsa aniq "{Kasb} bilan kirish" (masalan "Usta
            // bilan kirish"), bosilganda to'g'ridan-to'g'ri o'sha rolga
            // o'tadi. Bir nechta kasbi bo'lsa "Xodim sifatida kirish" —
            // bosilganda qaysi rolda ishlashini so'raydi (RolePickerSheet).
            if auth.appMode == .worker {
                Section {
                    NavigationLink(destination: PayslipsView()) {
                        Label("Ish haqim", systemImage: "banknote.fill")
                    }
                }
            }

            if let positions = user.positions, !positions.isEmpty {
                Section("Ko'rinish rejimi") {
                    Picker("Rejim", selection: Binding<AppMode>(
                        get: { auth.appMode },
                        set: { newValue in
                            if newValue == .customer {
                                auth.appMode = .customer
                            } else if positions.count == 1 {
                                auth.enterWorkerMode(positions[0])
                            } else {
                                showRolePicker = true
                            }
                        }
                    )) {
                        Text("Xaridor").tag(AppMode.customer)
                        Text(positions.count == 1 ? "\(positionInfo(positions[0]).label) bilan kirish" : "Xodim sifatida kirish")
                            .tag(AppMode.worker)
                    }
                    .pickerStyle(.segmented)
                    if auth.appMode == .worker, let active = auth.activePosition {
                        Text("Hozir: \(positionInfo(active).label)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .sheet(isPresented: $showRolePicker) {
                    RolePickerSheet(positions: positions) { chosen in
                        auth.enterWorkerMode(chosen)
                        showRolePicker = false
                    }
                }
            }

            if !invitations.isEmpty {
                Section("Ish takliflari") {
                    ForEach(invitations) { inv in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(inv.companyName).bold()
                            Text(inv.positions.joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary)
                            if inv.status == "pending" {
                                HStack {
                                    Button("Qabul qilish") { respond(inv, accept: true) }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.brandDeep)
                                    Button("Rad etish", role: .destructive) { respond(inv, accept: false) }
                                        .buttonStyle(.bordered)
                                }
                                .disabled(busyInvitationId == inv.id)
                                .font(.caption)
                            } else {
                                Text(inv.statusDisplay)
                                    .font(.caption).bold()
                                    .foregroundStyle(inv.status == "accepted" ? .green : .red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !career.isEmpty {
                Section("Ish tarixi (karyera)") {
                    ForEach(career) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.companyName).bold()
                                if entry.isActive {
                                    Text("hozir").font(.caption2).foregroundStyle(.green)
                                }
                            }
                            Text(entry.positions.joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Chiqish", role: .destructive) { auth.logout() }
            }

            Section("So'nggi buyurtmalar") {
                if isLoading {
                    ProgressView()
                } else if orders.isEmpty {
                    Text("Hali buyurtma yo'q").foregroundStyle(.secondary)
                } else {
                    // Ro'yxat cheklanadi: ega uchun kompaniyaning barcha buyurtmalari
                    // ko'p bo'lishi mumkin — bu yerda faqat so'nggilari ko'rsatiladi.
                    ForEach(orders.prefix(5)) { order in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.companyName).bold()
                            Text("\(order.totalPrice.formattedSom) so'm")
                                .font(.subheadline)
                            Text(order.statusDisplay)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.brandPrimary.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                    if orders.count > 5 {
                        Text("va yana \(orders.count - 5) ta buyurtma")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task { await loadAll() }
    }

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        async let ordersPage: Paginated<OrderSummary>? = try? APIClient.shared.get("/orders/", auth: true)
        async let invitationsPage: Paginated<EmployeeInvitation>? = try? APIClient.shared.get("/employee-invitations/", auth: true)
        async let careerPage: Paginated<CareerEntry>? = try? APIClient.shared.get("/users/me/career/", auth: true)
        orders = await ordersPage?.results ?? []
        invitations = await invitationsPage?.results ?? []
        career = await careerPage?.results ?? []
    }

    private func respond(_ inv: EmployeeInvitation, accept: Bool) {
        busyInvitationId = inv.id
        Task {
            defer { busyInvitationId = nil }
            do {
                let path = "/employee-invitations/\(inv.id)/\(accept ? "accept" : "decline")/"
                let _: EmployeeInvitation = try await APIClient.shared.post(path, auth: true)
                await auth.refreshUser()
                await loadAll()
            } catch {
                // jim turamiz — ro'yxat baribir yangilanadi keyingi safar
            }
        }
    }
}

/// Faqat telefon+SMS-OTP orqali kirish (email/parol olib tashlandi — bitta,
/// oddiy oqim). Bosqichlar: davlat+raqam → 6-xonali kod (qayta yuborish
/// countdown bilan) → (agar birinchi marta kirsa) ism/familiya so'raladi.
/// Flutter'dagi `lib/screens/auth_screen.dart` bilan bir xil oqim.
private struct AuthFormView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var locale: LocaleStore

    private static let otpLength = 6 // backend OTPRequestView: 6 xonali kod

    @State private var country = cisCountries[0]
    @State private var showCountryPicker = false
    @State private var phone = ""
    @State private var otpCode = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dob: Date?
    @State private var showDobPicker = false
    @State private var debugCode: String?
    @State private var step: Step = .phone
    // Har bir tugma faqat O'ZI bosilganda spinner ko'rsatishi uchun —
    // bitta umumiy `busy` bo'lsa, masalan Google bosilganda Telegram
    // tugmasi ham (aslida bosilmagan bo'lsa-da) "yuklanmoqda" bo'lib
    // ko'rinardi (barcha tugmalar bitta flagga qarab spinner chizardi).
    private enum BusyAction { case otp, verify, google, telegram, profile }
    @State private var busyAction: BusyAction?
    private var busy: Bool { busyAction != nil }
    @State private var resendSeconds = 0
    @State private var resendTimer: Timer?

    enum Step { case phone, code, profile }

    private var phoneValid: Bool { country.isValid(phone) }

    var body: some View {
        Form {
            switch step {
            case .phone: phoneSection
            case .code: codeSection
            case .profile: profileSection
            }

            if let error = auth.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .confirmationDialog(locale.t("auth_select_country"), isPresented: $showCountryPicker) {
            ForEach(cisCountries) { c in
                Button("\(c.flag) \(c.name) (\(c.dialCode))") {
                    country = c
                    if phone.count > c.phoneLength { phone = String(phone.prefix(c.phoneLength)) }
                }
            }
        }
        .onDisappear { resendTimer?.invalidate() }
    }

    @ViewBuilder
    private var phoneSection: some View {
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
                TextField(locale.t("auth_phone_hint"), text: $phone)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("authPhoneField")
                    .onChange(of: phone) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        phone = String(digits.prefix(country.phoneLength))
                    }
            }
            if !phone.isEmpty && !phoneValid {
                Text(locale.t("auth_phone_invalid")).font(.caption).foregroundStyle(.red)
            }
        }
        Section {
            Button(action: sendOTP) {
                if busyAction == .otp { ProgressView() } else { Text(locale.t("auth_send_code")).bold() }
            }
            .accessibilityIdentifier("authSendCodeButton")
            .disabled(!phoneValid || busy)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.brandDeep)
            .foregroundStyle(Color.brandPrimary)
        }
        Section {
            Button(action: loginWithGoogle) {
                if busyAction == .google {
                    ProgressView()
                } else {
                    HStack {
                        Image("google_logo").resizable().scaledToFit().frame(width: 20, height: 20)
                        Text("Google orqali kirish")
                    }
                }
            }
            .disabled(busy)
            .frame(maxWidth: .infinity)

            Button(action: loginWithTelegram) {
                if busyAction == .telegram {
                    ProgressView()
                } else {
                    HStack {
                        Image("telegram_logo").resizable().scaledToFit().frame(width: 20, height: 20)
                        Text("Telegram orqali kirish")
                    }
                }
            }
            .disabled(busy)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var codeSection: some View {
        Section {
            // SMS provayder hali ulanmagan — dev rejimda kod shu yerda ko'rsatiladi.
            Text(debugCode != nil ? "\(locale.t("auth_sms_sent")) (\(debugCode!))" : locale.t("auth_sms_sent"))
                .font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("authDebugCodeLabel")
            OtpBoxInput(code: $otpCode, length: Self.otpLength) { code in
                if !busy { verifyOTP(code) }
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 6)
            if busyAction == .verify {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        Section {
            Button {
                if resendSeconds == 0 { sendOTP() }
            } label: {
                Text(resendSeconds > 0 ? "\(locale.t("auth_resend")) (\(resendSeconds)s)" : locale.t("auth_resend"))
            }
            .disabled(resendSeconds > 0 || busy)
            Button(locale.t("auth_change_number")) { step = .phone }
                .font(.caption)
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        Section(locale.t("auth_profile_title")) {
            TextField(locale.t("auth_first_name"), text: $firstName)
            TextField(locale.t("auth_last_name"), text: $lastName)
            Button {
                showDobPicker = true
            } label: {
                HStack {
                    Text(locale.t("auth_dob"))
                    Spacer()
                    if let dob {
                        Text(dob.formatted(date: .numeric, time: .omitted)).foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)
            .sheet(isPresented: $showDobPicker) {
                NavigationStack {
                    DatePicker(
                        locale.t("auth_dob"), selection: Binding(get: { dob ?? Date() }, set: { dob = $0 }),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .navigationTitle(locale.t("auth_dob"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("OK") { showDobPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        Section {
            Button(action: saveProfile) {
                if busyAction == .profile { ProgressView() } else { Text(locale.t("auth_save")).bold() }
            }
            .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.brandDeep)
            .foregroundStyle(Color.brandPrimary)
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

    private func sendOTP() {
        busyAction = .otp
        Task {
            let result = await auth.requestOTP(phone: "\(country.dialCode)\(phone)")
            busyAction = nil
            if let result {
                debugCode = result.debugCode
                otpCode = ""
                step = .code
                startCountdown(result.resendAfter)
            }
        }
    }

    private func loginWithGoogle() {
        busyAction = .google
        Task {
            await auth.loginWithGoogle()
            busyAction = nil
            if auth.isAuthenticated && auth.isNewUser {
                // Google berilgan ism/familiya bo'lsa oldindan to'ldiramiz —
                // foydalanuvchi qayta yozib o'tirmasin.
                firstName = auth.user?.firstName ?? ""
                lastName = auth.user?.lastName ?? ""
                step = .profile
            }
        }
    }

    private func loginWithTelegram() {
        busyAction = .telegram
        Task {
            await auth.loginWithTelegram()
            busyAction = nil
            if auth.isAuthenticated && auth.isNewUser {
                firstName = auth.user?.firstName ?? ""
                lastName = auth.user?.lastName ?? ""
                step = .profile
            }
        }
    }

    private func verifyOTP(_ code: String) {
        busyAction = .verify
        Task {
            let ok = await auth.verifyOTP(phone: "\(country.dialCode)\(phone)", code: code)
            busyAction = nil
            if ok && auth.isNewUser {
                step = .profile
            }
        }
    }

    private func saveProfile() {
        busyAction = .profile
        let dobString: String? = dob.map {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: $0)
        }
        Task {
            await auth.completeProfile(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                dateOfBirth: dobString
            )
            busyAction = nil
        }
    }
}

struct OrderSummary: Codable, Identifiable {
    let id: String
    let companyName: String
    let statusDisplay: String
    let totalPrice: String
}

extension String {
    /// "1500000.00" -> "1 500 000"
    var formattedSom: String {
        guard let value = Double(self) else { return self }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? self
    }
}
