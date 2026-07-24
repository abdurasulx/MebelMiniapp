import SwiftUI

/// Savat — web `Cart.jsx` / Flutter `cart_screen.dart` bilan bir xil oqim:
/// bitta buyurtmada faqat bitta kompaniya bo'lishi shart (backend qoidasi),
/// shuning uchun checkout paytida kompaniya bo'yicha guruhlab, har biriga
/// alohida `/orders/` so'rovi yuboriladi.
struct CartView: View {
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var auth: AuthStore

    @State private var phone = ""
    @State private var address = ""
    @State private var note = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    var body: some View {
        NavigationStack {
            Group {
                if cart.items.isEmpty {
                    empty
                } else {
                    content
                }
            }
            .navigationTitle("Savat")
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart").font(.largeTitle).foregroundStyle(.secondary)
            Text("Savat bo'sh").font(.headline)
            Text("Katalogdan mahsulot tanlang").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        Form {
            Section("Mahsulotlar") {
                ForEach(cart.items) { item in
                    cartRow(item)
                }
            }
            Section("Yetkazish ma'lumotlari") {
                TextField("Telefon (+998…)", text: $phone).keyboardType(.phonePad)
                TextField("Manzil", text: $address)
                TextField("Izoh (ixtiyoriy)", text: $note)
            }
            Section {
                HStack {
                    Text("Jami")
                    Spacer()
                    Text("\(String(format: "%.0f", cart.total).formattedSom) so'm").bold()
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
            Section {
                Button(action: checkout) {
                    if busy { ProgressView() } else { Text("Buyurtma berish").bold() }
                }
                .disabled(phone.isEmpty || address.isEmpty || busy)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.brandDeep)
                .foregroundStyle(Color.brandPrimary)
            }
        }
        .alert("Buyurtma qabul qilindi", isPresented: $didSucceed) {
            Button("OK") {}
        } message: {
            Text("Kompaniya(lar) siz bilan tez orada bog'lanadi.")
        }
    }

    private func cartRow(_ item: CartItem) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: item.imageUrl ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.brandPrimary.opacity(0.3)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName).font(.subheadline).bold().lineLimit(1)
                Text("\(item.variantName) · \(item.companyName)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text("\(String(format: "%.0f", item.subtotal).formattedSom) so'm")
                    .font(.caption).bold()
            }

            Spacer()

            Stepper("\(item.qty)", value: Binding(
                get: { item.qty },
                set: { cart.setQty(item, qty: $0) }
            ), in: 1...50)
            .labelsHidden()
            .fixedSize()

            Button {
                cart.remove(item)
            } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
        }
    }

    private func checkout() {
        guard auth.isAuthenticated else {
            errorMessage = "Buyurtma berish uchun Profil bo'limidan tizimga kiring"
            return
        }
        busy = true
        errorMessage = nil
        struct Item: Encodable {
            let variant: String; let width: Double; let height: Double
            let depth: Double; let quantity: Int
        }
        struct Body: Encodable { let phone: String; let address: String; let note: String; let items: [Item] }
        struct AnyOrder: Decodable { let id: String }

        Task {
            do {
                for group in cart.byCompany.values {
                    let body = Body(
                        phone: phone, address: address, note: note,
                        items: group.map {
                            Item(variant: $0.variantId, width: $0.width, height: $0.height, depth: $0.depth, quantity: $0.qty)
                        }
                    )
                    let _: AnyOrder = try await APIClient.shared.post("/orders/", body: body, auth: true)
                }
                cart.clear()
                didSucceed = true
            } catch {
                errorMessage = error.localizedDescription
            }
            busy = false
        }
    }
}
