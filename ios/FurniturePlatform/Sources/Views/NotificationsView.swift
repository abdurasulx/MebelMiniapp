import SwiftUI

private func parseISODate(_ s: String) -> Date? {
    let f1 = ISO8601DateFormatter()
    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f1.date(from: s) { return d }
    let f2 = ISO8601DateFormatter()
    return f2.date(from: s)
}

private func timeAgo(_ iso: String) -> String {
    guard let date = parseISODate(iso) else { return "" }
    let diff = Date().timeIntervalSince(date)
    let minutes = Int(diff / 60)
    if minutes < 1 { return "hozir" }
    if minutes < 60 { return "\(minutes) daq oldin" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours) soat oldin" }
    return "\(hours / 24) kun oldin"
}

/// AppBar/toolbar'ga qo'yiladigan qo'ng'iroq — o'qilmagan sonini WebSocket
/// orqali real vaqtda oladi (avval 30s'da bir marta HTTP bilan so'ralardi,
/// qarang NotificationSocket.swift), bosilganda [NotificationsView]ni
/// ochadi.
struct NotificationBellButton: View {
    @State private var count = 0
    @State private var showList = false
    @State private var socket: NotificationSocket?

    var body: some View {
        Button {
            showList = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                if count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .task { await loadCount() }
        .onAppear {
            let s = NotificationSocket(onCount: { count = $0 })
            socket = s
            s.start()
        }
        .onDisappear {
            socket?.stop()
            socket = nil
        }
        .sheet(isPresented: $showList, onDismiss: { Task { await loadCount() } }) {
            NotificationsView()
        }
    }

    private func loadCount() async {
        struct Resp: Decodable { let count: Int }
        if let resp: Resp = try? await APIClient.shared.get("/notifications/unread_count/", auth: true) {
            count = resp.count
        }
    }
}

struct NotificationsView: View {
    @State private var items: [AppNotification] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false

    var body: some View {
        NavigationStack {
            Group {
                if isOffline && items.isEmpty && !isLoading {
                    OfflineView(onRetry: { Task { await load() } })
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).padding()
                } else if items.isEmpty {
                    Text("Hali xabarnoma yo'q.").foregroundStyle(.secondary)
                } else {
                    List(items) { n in
                        NotificationRow(notification: n, onTap: { Task { await markRead(n) } })
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Xabarnomalar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if items.contains(where: { !$0.isRead }) {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Hammasini o'qilgan qilish") { Task { await markAllRead() } }
                            .font(.caption)
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        isOffline = false
        do {
            let result: Paginated<AppNotification> = try await APIClient.shared.get("/notifications/", auth: true)
            items = result.results
        } catch {
            if OfflineView.isOffline(error) {
                isOffline = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func markRead(_ n: AppNotification) async {
        guard !n.isRead else { return }
        let _: AppNotification? = try? await APIClient.shared.post("/notifications/\(n.id)/mark_read/", auth: true)
        if let index = items.firstIndex(where: { $0.id == n.id }) {
            items[index] = AppNotification(
                id: n.id, notifType: n.notifType, notifTypeDisplay: n.notifTypeDisplay,
                title: n.title, body: n.body, isRead: true, createdAt: n.createdAt
            )
        }
    }

    private func markAllRead() async {
        struct Resp: Decodable { let status: String }
        let _: Resp? = try? await APIClient.shared.post("/notifications/mark_all_read/", auth: true)
        await load()
    }
}

private struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(notification.title).font(.subheadline).bold().foregroundStyle(.primary)
                    Spacer()
                    if !notification.isRead {
                        Circle().fill(Color.red).frame(width: 7, height: 7)
                    }
                }
                if !notification.body.isEmpty {
                    Text(notification.body).font(.caption).foregroundStyle(.secondary)
                }
                Text(timeAgo(notification.createdAt)).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .listRowBackground(notification.isRead ? Color.clear : Color.brandPrimary.opacity(0.06))
    }
}
