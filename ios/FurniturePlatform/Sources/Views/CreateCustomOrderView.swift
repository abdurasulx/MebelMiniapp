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
    @EnvironmentObject private var locale: LocaleStore
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
                TextField(locale.t("custom_order_customer_id"), text: $customerWorkerId)
                    .keyboardType(.numberPad)
                Text(locale.t("custom_order_customer_id_helper"))
                    .font(.caption).foregroundStyle(Color.textSecondary)
            }
            ForEach($items) { $item in
                Section {
                    Picker(locale.t("product_title"), selection: $item.productId) {
                        Text(locale.t("sel_choose")).tag(String?.none)
                        ForEach(products) { p in
                            Text(p.nameUz).tag(Optional(p.id))
                        }
                    }
                    HStack {
                        TextField(locale.t("dim_width"), text: $item.width).keyboardType(.decimalPad)
                        TextField(locale.t("dim_height"), text: $item.height).keyboardType(.decimalPad)
                        TextField(locale.t("custom_order_depth"), text: $item.depth).keyboardType(.decimalPad)
                    }
                    HStack {
                        TextField(locale.t("custom_order_quantity"), text: $item.quantity).keyboardType(.numberPad)
                        Toggle(locale.t("custom_order_price_later"), isOn: $item.isCustomSize)
                    }
                }
            }
            Button {
                items.append(OrderItemDraft())
            } label: {
                Label(locale.t("custom_order_add_item"), systemImage: "plus")
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(Color.appError)
            }

            Button {
                Task { await submit() }
            } label: {
                Text(isBusy ? locale.t("custom_order_submitting") : locale.t("custom_order_submit"))
            }
            .disabled(isBusy)
        }
        .navigationTitle(locale.t("worker_custom_order_tooltip"))
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
