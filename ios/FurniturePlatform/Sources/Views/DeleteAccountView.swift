import SwiftUI

private struct DeletionRequestDTO: Decodable {
    let id: String
    let status: String
}

private struct DeletionRequestBody: Encodable {
    let reason: String
}

/// Profildagi "Hisobni o'chirish" qatori — veb'dagi `DeleteAccountSection`
/// (Profile.jsx) bilan bir xil oqim: sabab bilan so'rov yuboriladi
/// (`/users/me/deletion-request/`), administrator ko'rib chiqib tasdiqlaydi.
/// App Store (Guideline 5.1.1(v)) talabi: o'chirishni ilovaning ichidan boshlash.
struct DeleteAccountSection: View {
    @EnvironmentObject private var locale: LocaleStore

    @State private var pending: Bool?   // nil = hali yuklanmoqda
    @State private var showForm = false

    var body: some View {
        Section {
            if pending == true {
                Label(locale.t("profile_delete_account_pending"), systemImage: "hourglass")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button(role: .destructive) {
                    showForm = true
                } label: {
                    Label(locale.t("profile_delete_account_title"), systemImage: "trash")
                }
                .disabled(pending == nil)
            }
        }
        .task { await loadPending() }
        .sheet(isPresented: $showForm) {
            DeleteAccountForm(onSubmitted: { pending = true })
        }
    }

    private func loadPending() async {
        do {
            let dto: DeletionRequestDTO? = try await APIClient.shared.get("/users/me/deletion-request/", auth: true)
            pending = dto != nil
        } catch {
            pending = false
        }
    }
}

private struct DeleteAccountForm: View {
    let onSubmitted: () -> Void

    @EnvironmentObject private var locale: LocaleStore
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(locale.t("profile_delete_account_desc"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    TextField(
                        locale.t("profile_delete_account_reason_placeholder"),
                        text: $reason, axis: .vertical
                    )
                    .lineLimit(3...6)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if busy { ProgressView() } else { Text(locale.t("profile_delete_account_submit")) }
                            Spacer()
                        }
                    }
                    .disabled(busy || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(locale.t("profile_delete_account_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.t("profile_delete_account_cancel")) { dismiss() }
                        .disabled(busy)
                }
            }
        }
    }

    private func submit() async {
        busy = true
        errorMessage = nil
        do {
            let _: DeletionRequestDTO = try await APIClient.shared.post(
                "/users/me/deletion-request/",
                body: DeletionRequestBody(reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)),
                auth: true
            )
            onSubmitted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        busy = false
    }
}
