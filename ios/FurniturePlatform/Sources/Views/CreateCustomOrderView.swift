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

    enum CodingKeys: String, CodingKey {
        case items
        case customerWorkerId = "customer_worker_id"
    }
}

/// Usta site-survey asosida CUSTOM_PROJECT buyurtmasini yaratadi.
struct CreateCustomOrderView: View {
    let survey: SiteSurvey
    @Environment(\.dismiss) private var dismiss

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
                Text("Mijoz shu ID orqali o'z ilovasida buyurtmani kuzatib borishi mumkin bo'ladi."
                     + (survey.customerName.map { " (hozir: \($0))" } ?? ""))
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
        .navigationTitle("Buyurtma yaratish")
        .task { await loadProducts() }
    }

    private func loadProducts() async {
        do {
            let page: Paginated<Product> = try await APIClient.shared.get(
                "/products/?company=\(survey.companySlug)", auth: true
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
            customerWorkerId: customerWorkerId
        )
        do {
            struct OrderResponse: Decodable { let id: String }
            let _: OrderResponse = try await APIClient.shared.post(
                "/site-surveys/\(survey.id)/create-order/", body: body, auth: true
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
