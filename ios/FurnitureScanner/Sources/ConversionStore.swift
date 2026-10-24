import Foundation
import SwiftUI

struct ConversionJob: Codable, Identifiable {
    var id: UUID = UUID()
    var serverID: String?
    var server: String
    var client: String
    var created = Date()
    var status = "uploading"
    var stage = "Rasm yuborilmoqda"
    var percent: Double = 0
    var position: Int?
    var error: String?
    var note: String?
    var resultURL: URL?
    var inputDimensions: [String: Double] = [:]
    var resultDimensions: [String: Double]?
    var isActive: Bool { ["uploading", "queued", "running"].contains(status) }
    var title: String {
        switch status {
        case "uploading": "Yuborilmoqda"
        case "queued": "Navbatda"
        case "running": "Tayyorlanmoqda"
        case "done": "Tayyor"
        case "uncertain": "Qabul qilinganini tekshiring"
        default: "Xatolik"
        }
    }
}

private struct RemoteJob: Decodable {
    let id: String
    let status: String
    let stage: String?
    let percent: Double?
    let position: Int?
    let error: String?
    let result: ResultFile?
    struct ResultFile: Decodable {
        let url: String?
        let note: String?
        let dims: Dimensions?
        struct Dimensions: Decodable {
            let width_cm: Double?
            let height_cm: Double?
            let depth_cm: Double?
        }
    }
}

@MainActor final class ConversionStore: ObservableObject {
    @Published private(set) var jobs: [ConversionJob] = []
    @Published var connectionError: String?
    @Published var storageError: String?
    private let history: URL
    private var refreshing = false

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Conversions", isDirectory: true)
        history = directory.appendingPathComponent("history.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: history.path) {
                jobs = try JSONDecoder().decode([ConversionJob].self, from: Data(contentsOf: history))
            }
            for i in jobs.indices where jobs[i].status == "uploading" {
                jobs[i].status = "uncertain"
                jobs[i].error = "Yuklash uzilgan. Server qabul qilgan bo‘lishi mumkin; avval yangilang."
            }
        } catch { storageError = "So‘rovlar tarixini o‘qib bo‘lmadi: \(error.localizedDescription)" }
    }

    private func save() {
        do { try JSONEncoder().encode(jobs).write(to: history, options: .atomic) }
        catch { storageError = "Tarixni saqlab bo‘lmadi: \(error.localizedDescription)" }
    }

    func submit(jpeg: Data, server: String, dimensions: [String: Double], textured: Bool) async throws {
        guard let base = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
              (base.scheme == "http" || base.scheme == "https"), base.host != nil,
              base.user == nil, base.password == nil, base.query == nil, base.fragment == nil,
              base.path.isEmpty || base.path == "/" else {
            throw ConversionError.message("Server manzilini http:// yoki https:// bilan kiriting, qo‘shimcha yo‘lsiz.")
        }
        guard !jpeg.isEmpty, jpeg.count <= 25 * 1024 * 1024,
              dimensions.values.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 5000 }) else {
            throw ConversionError.message("Rasm yoki o‘lcham noto‘g‘ri (0–5000 sm).")
        }
        // A distinct client per submission permits recovery after an ambiguous upload failure.
        let client = UUID().uuidString
        let job = ConversionJob(server: base.absoluteString, client: client, inputDimensions: dimensions)
        jobs.insert(job, at: 0)
        save()
        let boundary = UUID().uuidString
        var body = Data()
        func field(_ key: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("client", client); field("collection", "FurnitureScanner")
        field("roles", "front"); field("remove_bg", "1"); field("ai_prepare", "1")
        field("textured", textured ? "1" : "0")
        // Mesh estimates must not force an anisotropic deformation of the model.
        field("fit_dimensions", "0")
        for (key, value) in dimensions { field(key, String(value)) }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"\(client).jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = URLRequest(url: base.appendingPathComponent("api/convert"))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            try Self.check(response)
            let remote = try JSONDecoder().decode(RemoteJob.self, from: data)
            apply(remote, to: job.id)
        } catch {
            if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index].status = "uncertain"
                jobs[index].error = "\(error.localizedDescription) Server qabul qilgan bo‘lishi mumkin; yangilab tekshiring."
                save()
            }
            throw error
        }
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        var failures: [String] = []
        for job in jobs where ["queued", "running", "uncertain"].contains(job.status) {
            guard let base = URL(string: job.server),
                  var components = URLComponents(url: base.appendingPathComponent("api/jobs"), resolvingAgainstBaseURL: false) else { continue }
            components.queryItems = [URLQueryItem(name: "client", value: job.client)]
            guard let url = components.url else { continue }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, response) = try await URLSession.shared.data(for: request)
                try Self.check(response)
                let remoteJobs = try JSONDecoder().decode([RemoteJob].self, from: data)
                if let remote = remoteJobs.first(where: { job.serverID == nil || $0.id == job.serverID }) {
                    apply(remote, to: job.id)
                } else if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                    jobs[index].status = "uncertain"
                    jobs[index].error = "So‘rov server tarixida yo‘q. Server qayta ishga tushgan bo‘lishi mumkin."
                    save()
                }
            } catch { failures.append(error.localizedDescription) }
        }
        connectionError = failures.first
    }

    private func apply(_ remote: RemoteJob, to id: UUID) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].serverID = remote.id
        jobs[i].status = remote.status
        jobs[i].stage = remote.stage ?? remote.status
        jobs[i].percent = min(100, max(0, remote.percent ?? 0))
        jobs[i].position = remote.position
        jobs[i].error = remote.error
        jobs[i].note = remote.result?.note
        if let dims = remote.result?.dims {
            jobs[i].resultDimensions = ["width_cm": dims.width_cm, "height_cm": dims.height_cm, "depth_cm": dims.depth_cm]
                .compactMapValues { $0 }
        }
        if let path = remote.result?.url, let base = URL(string: jobs[i].server),
           let url = URL(string: path, relativeTo: base)?.absoluteURL,
           url.scheme == base.scheme, url.host == base.host, url.port == base.port {
            jobs[i].resultURL = url
        }
        save()
    }

    static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw ConversionError.message("Server javobi noto‘g‘ri.") }
        guard (200..<300).contains(http.statusCode) else {
            throw ConversionError.message(http.statusCode == 403
                ? "Kirish rad etildi. Telefonda Tailscale va ruxsat berilgan hisobni tekshiring."
                : "Server xatosi: HTTP \(http.statusCode).")
        }
    }
}

enum ConversionError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
