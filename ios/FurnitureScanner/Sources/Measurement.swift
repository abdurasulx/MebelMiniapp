import Foundation

struct FurnitureMeasurement: Codable, Equatable {
    let widthCentimeters: Double
    let heightCentimeters: Double
    let depthCentimeters: Double
    let sampledPoints: Int

    var volumeLiters: Double { widthCentimeters * heightCentimeters * depthCentimeters / 1_000 }
}

extension Double {
    var centimeterText: String {
        String(format: "%.1f cm", self)
    }
}
