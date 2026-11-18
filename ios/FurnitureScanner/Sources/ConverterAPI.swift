import Foundation
import UIKit

enum ConverterAPI {
    static let baseURL = URL(string: "http://100.90.116.106:5000")!

    static func submit(image: UIImage, measurement: FurnitureMeasurement, collection: String) async throws -> String {
        guard let jpeg = image.jpegData(compressionQuality: 0.88) else { throw URLError(.cannotDecodeContentData) }
        let boundary = "Scanner-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        field("collection", collection)
        field("roles", "front")
        field("height_cm", String(format: "%.1f", measurement.heightCentimeters))
        field("width_cm", String(format: "%.1f", measurement.widthCentimeters))
        field("depth_cm", String(format: "%.1f", measurement.depthCentimeters))
        field("remove_bg", "1")
        field("textured", "1")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"scan.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpeg)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: baseURL.appending(path: "api/convert"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["id"] as? String) ?? "qabul qilindi"
    }
}
