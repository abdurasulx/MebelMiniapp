import simd
import SwiftUI

struct ProductDetailView: View {
    let productId: String

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var cart: CartStore
    @State private var product: Product?
    @State private var addedToCart = false
    @State private var selectedVariant: Variant?
    @State private var width: String = ""
    @State private var height: String = ""
    @State private var depth: String = ""
    @State private var quantity = 1
    @State private var errorMessage: String?
    @State private var showAR = false
    @State private var showOrderSheet = false

    private var price: Double? {
        guard let variant = selectedVariant,
              let w = Double(width), let h = Double(height), let d = Double(depth),
              w > 0, h > 0, d > 0 else { return nil }
        return variant.basePriceValue * w * h * d * Double(quantity)
    }

    /// Kiritilgan eni/bo'yi/chuqurlikning variant standart o'lchamiga nisbati —
    /// AR'da modelga shu nisbatda qo'llaniladi, shunda AR'da ko'rilgan buyum
    /// sahifadagi narxga mos o'lchamda ko'rinadi (aks holda AR har doim faylning
    /// standart o'lchamini ko'rsatardi, kiritilgan o'lchamdan qat'iy nazar).
    private var arScaleFactors: SIMD3<Float> {
        guard let variant = selectedVariant,
              let w = Double(width), let h = Double(height), let d = Double(depth),
              w > 0, h > 0, d > 0 else { return [1, 1, 1] }
        return [
            Float(w / variant.widthValue),
            Float(h / variant.heightValue),
            Float(d / variant.depthValue),
        ]
    }

    var body: some View {
        ScrollView {
            if let product {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .topTrailing) {
                        gallery(product)

                        HStack(spacing: 8) {
                            LikeButton(productId: product.id, compact: false)
                            ShareLink(
                                item: "\(product.nameUz) — \(product.companyName)\nFurniture Platform ilovasida ko'ring."
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .padding(8)
                                    .background(.white, in: Circle())
                            }
                        }
                        .padding(12)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.nameUz).font(.title2).bold()
                        if let companySlug = product.companySlug {
                            NavigationLink(destination: CompanyShopView(companySlug: companySlug)) {
                                HStack(spacing: 4) {
                                    Text("🏭 \(product.companyName)")
                                    Image(systemName: "chevron.right").font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("🏭 \(product.companyName)").foregroundStyle(.secondary)
                        }
                        if product.branchViloyatDisplay != nil || (product.branchAddress?.isEmpty == false) {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse").font(.caption2)
                                Text(
                                    [product.branchViloyatDisplay, product.branchAddress]
                                        .compactMap { $0 }
                                        .filter { !$0.isEmpty }
                                        .joined(separator: ", ")
                                )
                                .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        if let description = product.description, !description.isEmpty {
                            Text(description).font(.subheadline).padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)

                    if !product.variants.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            // 1) Avval variant (rang/material) tanlanadi
                            Text("Variant (material/rang)").font(.caption).foregroundStyle(.secondary)
                            Picker("Variant", selection: $selectedVariant) {
                                ForEach(product.variants) { v in
                                    Text(v.name)
                                        .tag(Optional(v))
                                }
                            }
                            .pickerStyle(.segmented)

                            // 2) Bitta model butun mahsulotga tegishli — faqat rang/naqsh
                            // tanlangan variantga qarab AR'da runtime'da almashadi. Tugma
                            // matni ATAYIN variant nomini o'z ichiga olmaydi (sodda va
                            // barqaror matn) — variant almashgani `.id()` orqali sahna
                            // qayta yaratilishida aks etadi.
                            if let usdz = product.model3d?.usdzUrl {
                                Button {
                                    showAR = true
                                } label: {
                                    Label("AR'da sinash", systemImage: "arkit")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.brandDeep)
                                        .foregroundStyle(Color.brandPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .accessibilityIdentifier("arButton-\(selectedVariant?.id ?? "")")
                                .id("\(usdz)-\(selectedVariant?.id ?? "")") // variant almashsa tugma qayta yaratiladi
                            } else if product.model3d?.glbUrl != nil {
                                Text("🧊 3D model mavjud (AR uchun iOS'da USDZ kerak)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 12) {
                                dimField("Eni (m)", $width)
                                dimField("Bo'yi (m)", $height)
                                dimField("Chuquri (m)", $depth)
                            }

                            Stepper("Soni: \(quantity)", value: $quantity, in: 1...50)

                            if let price {
                                VStack(alignment: .leading) {
                                    Text("Taxminiy narx").font(.caption).foregroundStyle(.secondary)
                                    Text("\(String(format: "%.0f", price).formattedSom) so'm").font(.title3).bold()
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.brandPrimary.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(.red).font(.caption)
                            }

                            Button {
                                if auth.isAuthenticated { showOrderSheet = true }
                                else { errorMessage = "Buyurtma berish uchun Profil bo'limidan tizimga kiring" }
                            } label: {
                                Text("📦 Buyurtma berish")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(price == nil ? Color.gray.opacity(0.4) : Color.brandSecondary)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(price == nil)

                            Button {
                                guard let variant = selectedVariant else { return }
                                cart.addProduct(product, variant: variant)
                                addedToCart = true
                            } label: {
                                Label("Savatga qo'shish", systemImage: "cart.badge.plus")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandDeep, lineWidth: 1.5))
                                    .foregroundStyle(Color.brandDeep)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Savatga qo'shildi", isPresented: $addedToCart) {
            Button("OK") {}
        }
        .onChange(of: selectedVariant?.id) { _, _ in
            guard let v = selectedVariant else { return }
            width = v.width
            height = v.height
            depth = v.depth
        }
        .fullScreenCover(isPresented: $showAR) {
            if let urlString = product?.model3d?.usdzUrl, let url = URL(string: urlString) {
                ARPlacementView(
                    usdzURL: url,
                    title: "\(product?.nameUz ?? "") — \(selectedVariant?.name ?? "")",
                    colorHex: selectedVariant?.colorHex,
                    textureURL: selectedVariant?.textureUrl.flatMap(URL.init(string:)),
                    scaleFactors: arScaleFactors
                )
            }
        }
        .sheet(isPresented: $showOrderSheet) {
            if let product, let variant = selectedVariant,
               let w = Double(width), let h = Double(height), let d = Double(depth) {
                OrderCheckoutView(
                    productName: product.nameUz,
                    variantId: variant.id,
                    width: w, height: h, depth: d, quantity: quantity,
                    total: price ?? 0
                )
            }
        }
    }

    @ViewBuilder
    private func gallery(_ product: Product) -> some View {
        let urls = product.galleryUrls
        if urls.count > 1 {
            TabView {
                ForEach(urls, id: \.self) { url in
                    AsyncImage(url: URL(string: url)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.brandPrimary.opacity(0.3)
                        }
                    }
                    .clipped()
                }
            }
            .tabViewStyle(.page)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            AsyncImage(url: URL(string: urls.first ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.brandPrimary.opacity(0.3)
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func dimField(_ label: String, _ value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("0.0", text: value)
                .keyboardType(.decimalPad)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func load() async {
        do {
            let p: Product = try await APIClient.shared.get("/products/\(productId)/", auth: true)
            product = p
            if let first = p.variants.first {
                selectedVariant = first
                width = first.width
                height = first.height
                depth = first.depth
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Variant: Hashable {
    static func == (lhs: Variant, rhs: Variant) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
