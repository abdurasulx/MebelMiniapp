import SwiftUI
import UIKit

/// `AsyncImage` o'rniga: rasm xotirada (NSCache) va diskda (URLCache) saqlanadi —
/// ekranga qayta kirganda yoki ilova qayta ochilganda qayta yuklanmaydi.
/// API `AsyncImage(url:transaction:content:)` bilan bir xil.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    var transaction: Transaction = Transaction()
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase

    init(
        url: URL?,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.transaction = transaction
        self.content = content
        // Xotirada bo'lsa birinchi kadrdan ko'rsatiladi (miltillashsiz).
        if let url, let image = ImageLoader.shared.memoryImage(for: url) {
            _phase = State(initialValue: .success(Image(uiImage: image)))
        } else {
            _phase = State(initialValue: .empty)
        }
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }
        if case .success = phase, ImageLoader.shared.memoryImage(for: url) != nil { return }
        do {
            let image = try await ImageLoader.shared.image(for: url)
            withTransaction(transaction) { phase = .success(Image(uiImage: image)) }
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            phase = .failure(error)
        }
    }
}

final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()

    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        memory.countLimit = 200
        let config = URLSessionConfiguration.default
        // Server kesh sarlavhalarini bermasa ham diskdagi nusxa ishlatiladi.
        config.urlCache = URLCache(memoryCapacity: 30 * 1024 * 1024, diskCapacity: 400 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    func memoryImage(for url: URL) -> UIImage? { memory.object(forKey: url as NSURL) }

    func image(for url: URL) async throws -> UIImage {
        if let hit = memoryImage(for: url) { return hit }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }
}
