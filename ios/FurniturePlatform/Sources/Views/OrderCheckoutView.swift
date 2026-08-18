import SwiftUI

struct OrderCheckoutView: View {
    let productName: String
    let variantId: String
    let width: Double
    let height: Double
    let depth: Double
    let quantity: Int
    let total: Double

    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var address = ""
    @State private var note = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    // Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
    // foydalanuvchi uchun backend 403 qaytaradi — qarang submit().
    @State private var showPhoneVerify = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Mahsulot") {
                    Text(productName)
                    Text("\(width, specifier: "%.2f") × \(height, specifier: "%.2f") × \(depth, specifier: "%.2f") m ×\(quantity)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(String(format: "%.0f", total).formattedSom) so'm").bold()
                }
                Section("Yetkazish ma'lumotlari") {
                    TextField("Telefon (+998…)", text: $phone).keyboardType(.phonePad)
                    TextField("Manzil", text: $address)
                    TextField("Izoh (ixtiyoriy)", text: $note)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button(action: submit) {
                        if busy { ProgressView() } else { Text("Buyurtmani tasdiqlash").bold() }
                    }
                    .disabled(phone.isEmpty || address.isEmpty || busy)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.brandDeep)
                    .foregroundStyle(Color.brandPrimary)
                }
            }
            .navigationTitle("Buyurtma berish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
            }
            .alert("Buyurtma qabul qilindi", isPresented: $didSucceed) {
                Button("OK") { dismiss() }
            } message: {
                Text("Kompaniya siz bilan tez orada bog'lanadi.")
            }
            .sheet(isPresented: $showPhoneVerify) {
                PhoneVerifySheet(initialPhone: phone, onVerified: submit)
            }
        }
    }

    private func submit() {
        busy = true
        errorMessage = nil
        struct Item: Encodable {
            let variant: String; let width: Double; let height: Double
            let depth: Double; let quantity: Int
        }
        struct Body: Encodable { let phone: String; let address: String; let note: String; let items: [Item] }
        let body = Body(
            phone: phone, address: address, note: note,
            items: [Item(variant: variantId, width: width, height: height, depth: depth, quantity: quantity)]
        )
        Task {
            do {
                struct AnyOrder: Decodable { let id: String }
                let _: AnyOrder = try await APIClient.shared.post("/orders/", body: body, auth: true)
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
