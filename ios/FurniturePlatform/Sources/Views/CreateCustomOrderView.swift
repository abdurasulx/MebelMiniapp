import SwiftUI

private struct OrderItemDraft: Identifiable {
    let id = UUID()
    var productId: String?
    var width = "1"
    var height = "1"
    var depth = "1"
    var quantity = "1"
    var isCustomSize = true
}

private struct CreateOrderItemBody: Encodable {
    let product: String
    let width: Double
    let height: Double
    let depth: Double
    let quantity: Int
    let isCustomSize: Bool

    enum CodingKeys: String, CodingKey {
        case product, width, height, depth, quantity
        case isCustomSize = "is_custom_size"
    }
}

private struct CreateOrderBody: Encodable {
    let items: [CreateOrderItemBody]
    let customerWorkerId: String
    let latitude: Double?
    let longitude: Double?
    let accuracy: Double?
    let isMock: Bool
    let deviceTimestamp: String?
    let platform: String

    enum CodingKeys: String, CodingKey {
        case items
        case customerWorkerId = "customer_worker_id"
        case latitude, longitude, accuracy
        case isMock = "is_mock"
        case deviceTimestamp = "device_timestamp"
        case platform
    }
}

/// Usta mijoz uyida turib to'g'ridan-to'g'ri individual (CUSTOM_PROJECT)
/// buyurtma yaratadi — alohida "joy o'rganish" bosqichi endi yo'q (qarang
/// backend apps.custom_orders.services.create_custom_order_on_site).
/// Qurilmadan joylashuv olinadi va soxta (mock) GPS aniqlansa ham buyurtma
/// baribir yaratiladi, lekin backend firma egasiga xabar beradi (Davomat
/// check-in bilan bir xil `is_mock` naqshi, qarang AttendanceView.swift).
struct CreateCustomOrderView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    private let locationManager = AttendanceLocationManager()

    @State private var products: [Product] = []
    @State private var items: [OrderItemDraft] = [OrderItemDraft()]
    @State private var customerWorkerId = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Mijoz qidiruvchi ID", text: $customerWorkerId)
                    .keyboardType(.numberPad)
                Text("Mijoz shu ID orqali o'z ilovasida buyurtmani kuzatib borishi mumkin bo'ladi.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach($items) { $item in
                Section {
                    Picker("Mahsulot", selection: $item.productId) {
                        Text("— tanlang —").tag(String?.none)
                        ForEach(products) { p in
                            Text(p.nameUz).tag(Optional(p.id))
                        }
                    }
                    HStack {
                        TextField("Eni", text: $item.width).keyboardType(.decimalPad)
                        TextField("Bo'yi", text: $item.height).keyboardType(.decimalPad)
                        TextField("Chuquri", text: $item.depth).keyboardType(.decimalPad)
                    }
                    HStack {
                        TextField("Soni", text: $item.quantity).keyboardType(.numberPad)
                        Toggle("Narx keyinroq", isOn: $item.isCustomSize)
                    }
                }
            }
            Button {
                items.append(OrderItemDraft())
            } label: {
                Label("Band qo'shish", systemImage: "plus")
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            Button {
                Task { await submit() }
            } label: {
                Text(isBusy ? "Yaratilmoqda…" : "Buyurtma yaratish")
            }
            .disabled(isBusy)
        }
        .navigationTitle("Individual loyiha")
        .task { await loadProducts() }
    }

    private func loadProducts() async {
        guard let companySlug = auth.user?.company?.slug else { return }
        do {
            let page: Paginated<Product> = try await APIClient.shared.get(
                "/products/?company=\(companySlug)", auth: true
            )
            products = page.results
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        var latitude: Double?
        var longitude: Double?
        var accuracy: Double?
        var isMock = false
        var deviceTimestamp: String?
        if let location = try? await locationManager.currentLocation() {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            accuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
            isMock = location.isSimulated
            deviceTimestamp = ISO8601DateFormatter().string(from: location.timestamp)
        }

        let body = CreateOrderBody(
            items: items.compactMap { item in
                guard let productId = item.productId else { return nil }
                return CreateOrderItemBody(
                    product: productId,
                    width: Double(item.width) ?? 1,
                    height: Double(item.height) ?? 1,
                    depth: Double(item.depth) ?? 1,
                    quantity: Int(item.quantity) ?? 1,
                    isCustomSize: item.isCustomSize
                )
            },
            customerWorkerId: customerWorkerId,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            isMock: isMock,
            deviceTimestamp: deviceTimestamp,
            platform: "ios"
        )
        do {
            struct OrderResponse: Decodable { let id: String }
            let _: OrderResponse = try await APIClient.shared.post(
                "/custom-orders/create/", body: body, auth: true
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
