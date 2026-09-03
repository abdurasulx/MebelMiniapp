import Foundation

/// Bildirishnoma qo'ng'irog'i sonini real vaqtda yangilash — avval har 30s'da
/// bir marta `/notifications/unread_count/` so'ralardi (qarang
/// NotificationsView.swift eski tarixi), endi backend
/// `apps/notifications/consumers.py`ga WebSocket orqali ulanadi (native
/// `URLSessionWebSocketTask` — qo'shimcha paket kerak emas). Ulanish uzilsa
/// eksponensial orqaga chekinish bilan qayta ulanadi — token har safar QAYTA
/// (`APIClient.shared.currentAccessToken`) o'qiladi.
final class NotificationSocket: NSObject {
    private var task: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .default)
    private var retryDelay: TimeInterval = 1
    private var stopped = false
    private let onCount: (Int) -> Void

    init(onCount: @escaping (Int) -> Void) {
        self.onCount = onCount
    }

    private func wsURL(token: String) -> URL? {
        var base = APIConfig.baseURL.absoluteString
        if base.hasSuffix("/api/v1/") {
            base.removeLast("/api/v1/".count)
        } else if base.hasSuffix("/api/v1") {
            base.removeLast("/api/v1".count)
        }
        if base.hasPrefix("https://") {
            base = "wss://" + base.dropFirst("https://".count)
        } else if base.hasPrefix("http://") {
            base = "ws://" + base.dropFirst("http://".count)
        }
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        return URL(string: "\(base)/ws/notifications/?token=\(encodedToken)")
    }

    func start() {
        stopped = false
        Task { await connect() }
    }

    private func connect() async {
        guard !stopped else { return }
        let token = await APIClient.shared.currentAccessToken
        guard let token, let url = wsURL(token: token) else { return }
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        listen()
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.retryDelay = 1
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   obj["type"] as? String == "unread_count",
                   let count = obj["count"] as? Int {
                    DispatchQueue.main.async { self.onCount(count) }
                }
                self.listen()
            case .failure:
                self.scheduleRetry()
            }
        }
    }

    private func scheduleRetry() {
        guard !stopped else { return }
        let delay = retryDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { await self?.connect() }
        }
        retryDelay = min(retryDelay * 2, 30)
    }

    func stop() {
        stopped = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }
}
