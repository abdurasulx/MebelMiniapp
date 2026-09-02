import SwiftUI

/// Savat — web `Cart.jsx` / Flutter `cart_screen.dart` bilan bir xil oqim:
/// bitta buyurtmada faqat bitta kompaniya bo'lishi shart (backend qoidasi),
/// shuning uchun checkout paytida kompaniya bo'yicha guruhlab, har biriga
/// alohida `/orders/` so'rovi yuboriladi.
struct CartView: View {
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var location: LocationStore

    @State private var busy = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    // Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
    // foydalanuvchi uchun backend 403 qaytaradi — qarang checkout().
    @State private var showPhoneVerify = false

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
                .disabled(busy)
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
        .sheet(isPresented: $showPhoneVerify) {
            PhoneVerifySheet(initialPhone: auth.user?.phone ?? "", onVerified: checkout)
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
        // Telefon/manzil endi so'ralmaydi — tasdiqlangan profildan (backend
        // `request.user.phone`) va shu yerdagi GPS'dan (`LocationStore`)
        // avtomatik olinadi. Agar hali aniqlanmagan bo'lsa, so'rab ko'ramiz
        // (ruxsat allaqachon berilgan bo'lsa darhol qaytadi) — lekin
        // topilmasa ham buyurtmani to'xtatmaymiz (koordinatasiz yuboriladi).
        if location.lat == nil { location.detectFromGps() }
        busy = true
        errorMessage = nil
        struct Item: Encodable {
            let variant: String; let width: Double; let height: Double
            let depth: Double; let quantity: Int
        }
        struct Body: Encodable { let latitude: Double?; let longitude: Double?; let items: [Item] }
        struct AnyOrder: Decodable { let id: String }

        Task {
            do {
                for group in cart.byCompany.values {
                    let body = Body(
                        latitude: location.lat, longitude: location.lng,
                        items: group.map {
                            Item(variant: $0.variantId, width: $0.width, height: $0.height, depth: $0.depth, quantity: $0.qty)
                        }
                    )
                    let _: AnyOrder = try await APIClient.shared.post("/orders/", body: body, auth: true)
                }
                cart.clear()
                didSucceed = true
            } catch let error as APIError {
                if case .server(let msg, let statusCode) = error, statusCode == 403, msg.contains("tasdiqlang") {
                    showPhoneVerify = true
                } else {
                    errorMessage = error.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            busy = false
        }
    }
}
