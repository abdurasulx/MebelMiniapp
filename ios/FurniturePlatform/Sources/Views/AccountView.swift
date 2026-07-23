import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            Group {
                if let user = auth.user {
                    ProfileView(user: user)
                } else {
                    AuthFormView()
                }
            }
            .navigationTitle("Profil")
        }
    }
}

private struct ProfileView: View {
    let user: User
    @EnvironmentObject private var auth: AuthStore
    @State private var orders: [OrderSummary] = []
    @State private var invitations: [EmployeeInvitation] = []
    @State private var career: [CareerEntry] = []
    @State private var isLoading = false
    @State private var busyInvitationId: String?

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

            // Faqat biror firmada ishlagan/ishlayotgan foydalanuvchida ko'rinadi —
            // xaridor sifatida ilovadan foydalanish yoki usta ish rejimiga o'tish.
            if user.company != nil || !career.isEmpty {
                Section("Ko'rinish rejimi") {
                    Picker("Rejim", selection: $auth.appMode) {
                        Text("Xaridor").tag(AppMode.customer)
                        Text("Usta").tag(AppMode.worker)
                    }
                    .pickerStyle(.segmented)
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

private struct AuthFormView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var loginKind: LoginKind = .phone
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var phone = ""
    @State private var otpCode = ""
    @State private var debugCode: String?
    @State private var otpStep: OTPStep = .enterPhone
    @State private var busy = false

    enum Mode { case login, register }
    enum LoginKind { case phone, email }
    enum OTPStep { case enterPhone, enterCode }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $loginKind) {
                    Text("Telefon (SMS)").tag(LoginKind.phone)
                    Text("Email").tag(LoginKind.email)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
            }

            if loginKind == .phone {
                phoneSection
            } else {
                emailSection
            }

            if let error = auth.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
    }

    @ViewBuilder
    private var phoneSection: some View {
        if otpStep == .enterPhone {
            Section {
                TextField("Telefon (+998…)", text: $phone).keyboardType(.phonePad)
            }
            Section {
                Button(action: sendOTP) {
                    if busy { ProgressView() } else { Text("Kod yuborish").bold() }
                }
                .disabled(phone.isEmpty || busy)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.brandDeep)
                .foregroundStyle(Color.brandPrimary)
            }
        } else {
            Section {
                // SMS provayder hali ulanmagan — dev rejimda kod shu yerda ko'rsatiladi.
                Text(debugCode != nil ? "SMS yuborildi (\(debugCode!))" : "SMS yuborildi")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Kod (6 raqam)", text: $otpCode).keyboardType(.numberPad)
            }
            Section {
                Button(action: verifyOTP) {
                    if busy { ProgressView() } else { Text("Kirish").bold() }
                }
                .accessibilityIdentifier("authSubmitButton")
                .disabled(otpCode.isEmpty || busy)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.brandDeep)
                .foregroundStyle(Color.brandPrimary)
                Button("Raqamni o'zgartirish") { otpStep = .enterPhone }
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var emailSection: some View {
        Section {
            Picker("", selection: $mode) {
                Text("Kirish").tag(Mode.login)
                Text("Ro'yxatdan o'tish").tag(Mode.register)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 4)
        }

        if mode == .register {
            Section {
                TextField("Ism", text: $firstName)
                TextField("Telefon (+998…)", text: $phone).keyboardType(.phonePad)
            }
        }

        Section {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            SecureField("Parol", text: $password)
        }

        Section {
            Button(action: submitEmail) {
                if busy { ProgressView() } else { Text(mode == .login ? "Kirish" : "Ro'yxatdan o'tish").bold() }
            }
            .accessibilityIdentifier("authSubmitButton")
            .disabled(email.isEmpty || password.isEmpty || busy)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.brandDeep)
            .foregroundStyle(Color.brandPrimary)
        }
    }

    private func sendOTP() {
        busy = true
        Task {
            debugCode = await auth.requestOTP(phone: phone)
            if auth.errorMessage == nil { otpStep = .enterCode }
            busy = false
        }
    }

    private func verifyOTP() {
        busy = true
        Task {
            await auth.verifyOTP(phone: phone, code: otpCode)
            busy = false
        }
    }

    private func submitEmail() {
        busy = true
        Task {
            if mode == .login {
                await auth.login(email: email, password: password)
            } else {
                await auth.register(email: email, password: password, firstName: firstName, phone: phone)
            }
            busy = false
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
