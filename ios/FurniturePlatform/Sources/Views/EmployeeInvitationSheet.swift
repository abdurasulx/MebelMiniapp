import SwiftUI

/// "Ishga taklif" bildirishnomasi bosilganda ochiladigan alohida oyna —
/// kutilayotgan takliflar shu yerning o'zida qabul/rad etiladi (Profilda
/// inline ro'yxat yo'q).
struct EmployeeInvitationSheet: View {
    @EnvironmentObject private var locale: LocaleStore
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var pending: [EmployeeInvitation] = []
    @State private var isLoading = true
    @State private var busyId: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if pending.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(Color.textSecondary)
                        Text(errorMessage ?? locale.t("Hozircha taklif yo'q"))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(pending) { inv in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(inv.companyName).font(.headline)
                            Text(inv.positions.map { locale.position($0).label }.joined(separator: ", "))
                                .font(.subheadline).foregroundStyle(Color.textSecondary)
                            HStack {
                                Button(locale.t("Qabul qilish")) { respond(inv, accept: true) }
                                    .buttonStyle(.borderedProminent).tint(.brandDeep)
                                Button(locale.t("Rad etish"), role: .destructive) { respond(inv, accept: false) }
                                    .buttonStyle(.bordered)
                            }
                            .disabled(busyId == inv.id)
                        }
                        .padding(.vertical, 6)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(locale.t("Ish takliflari"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.t("common_close")) { dismiss() }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func load() async {
        isLoading = true
        let page: Paginated<EmployeeInvitation>? = try? await APIClient.shared.get(
            "/employee-invitations/?received=1", auth: true
        )
        pending = (page?.results ?? []).filter { $0.status == "pending" }
        isLoading = false
    }

    private func respond(_ inv: EmployeeInvitation, accept: Bool) {
        busyId = inv.id
        Task {
            defer { busyId = nil }
            do {
                let path = "/employee-invitations/\(inv.id)/\(accept ? "accept" : "decline")/"
                let _: EmployeeInvitation = try await APIClient.shared.post(path, auth: true)
                await auth.refreshUser()
                await load()
                if pending.isEmpty { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
