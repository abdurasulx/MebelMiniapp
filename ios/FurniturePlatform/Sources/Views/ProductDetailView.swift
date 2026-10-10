import simd
import SwiftUI

struct ProductDetailView: View {
    let productId: String

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var locale: LocaleStore
    @State private var product: Product?
    @State private var addedToCart = false
    @State private var selectedVariant: Variant?
    @State private var width: String = ""
    @State private var height: String = ""
    @State private var depth: String = ""
    @State private var quantity = 1
    @State private var errorMessage: String?
    @State private var showAR = false
    // Rasm galereyasi: sahifadagi joriy rasm va to'liq ekranli galereya
    // bir xil `galleryIndex`ni bo'lishadi (sinxron).
    @State private var galleryIndex = 0
    @State private var showGallery = false
    @State private var showOrderSheet = false

    private var price: Double? {
        guard let variant = selectedVariant,
              let w = Double(width), let h = Double(height), let d = Double(depth),
              w > 0, h > 0, d > 0 else { return nil }
        return variant.effectivePriceValue * w * h * d * Double(quantity)
    }

    /// Kiritilgan eni/bo'yi/chuqurlikning variant standart o'lchamiga nisbati —
    /// AR'da modelga shu nisbatda qo'llaniladi, shunda AR'da ko'rilgan buyum
    /// sahifadagi narxga mos o'lchamda ko'rinadi (aks holda AR har doim faylning
    /// standart o'lchamini ko'rsatardi, kiritilgan o'lchamdan qat'iy nazar).
    // Tanlangan variant o'zining alohida (tayyor) 3D modeliga ega bo'lsa —
    // shuni, aks holda mahsulotning umumiy modelini ishlatamiz (web'dagi
    // ProductDetail.jsx: `hasOwnModel`/`activeModel3d` bilan bir xil naqsh —
    // avval bu yerda unutilgan bo'lib, variant darajasidagi yuklangan
    // fayllar iOS AR'da hech qachon ko'rinmas edi).
    private var activeModel3d: Model3D? {
        if let vm = selectedVariant?.model3d, vm.status == "ready" {
            return vm
        }
        return product?.model3d
    }

    // Ko'rsatiladigan o'lcham — variantning qo'lda kiritiladigan (hozir
    // doim standart 1x1x1 bo'lib qolgan) maydonidan emas, 3D model
    // faylining o'zidan (geometriyadan) hisoblangan haqiqiy o'lchamdan
    // (`bbox_*`) olinadi; narx/AR hisob-kitobi esa hamon variant qiymatiga
    // (`width`/`height`/`depth` holat o'zgaruvchilari) asoslanadi — ular
    // shu yerda o'zgartirilmaydi, faqat KO'RSATILADIGAN matn boshqa manbadan.
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
                            LikeButton(productId: product.id, compact: false, product: product)
                            ShareLink(
                                item: "\(product.nameUz) — \(product.companyName)\(locale.t("product_share_suffix"))"
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
                                    if product.isVerified { VerifiedBadgeView(compact: true) }
                                    Image(systemName: "chevron.right").font(.caption2)
                                }
                                .foregroundStyle(Color.textSecondary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Text("🏭 \(product.companyName)")
                                if product.isVerified { VerifiedBadgeView(compact: true) }
                            }
                            .foregroundStyle(Color.textSecondary)
                        }
                        if product.companyViloyatDisplay != nil || (product.companyAddress?.isEmpty == false) {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse").font(.caption2)
                                Text(
                                    [product.companyViloyatDisplay, product.companyAddress]
                                        .compactMap { $0 }
                                        .filter { !$0.isEmpty }
                                        .joined(separator: ", ")
                                )
                                .font(.caption)
                            }
                            .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .padding(.horizontal)

                    if !product.variants.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            if let variant = selectedVariant {
                                PriceBlockView(pricing: variant.effectivePricing)
                            }

                            // 1) Avval variant (rang/material) tanlanadi
                            Text(locale.t("product_variant_field_label")).font(.caption).foregroundStyle(Color.textSecondary)
                            Picker("Variant", selection: $selectedVariant) {
                                ForEach(product.variants) { v in
                                    Text(v.name)
                                        .tag(Optional(v))
                                }
                            }
                            .pickerStyle(.segmented)

                            // O'lcham chizmasi (quti: eni/bo'yi/chuqurligi + hajm)
                            if let dims = DimensionBoxView.resolve(model: activeModel3d, variant: selectedVariant) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(locale.t("dim_title")).font(.subheadline).fontWeight(.bold)
                                    DimensionBoxView(widthM: dims.w, heightM: dims.h, depthM: dims.d)
                                }
                            }

                            if let description = product.description, !description.isEmpty {
                                Text(description).font(.subheadline)
                            }

                            // 2) Bitta model butun mahsulotga tegishli — faqat rang/naqsh
                            // tanlangan variantga qarab AR'da runtime'da almashadi. Tugma
                            // matni ATAYIN variant nomini o'z ichiga olmaydi (sodda va
                            // barqaror matn) — variant almashgani `.id()` orqali sahna
                            // qayta yaratilishida aks etadi.
                            if let usdz = activeModel3d?.usdzUrl {
                                Button {
                                    showAR = true
                                } label: {
                                    Label(locale.t("product_try_ar"), systemImage: "arkit")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.brandDeep)
                                        .foregroundStyle(Color.brandPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .accessibilityIdentifier("arButton-\(selectedVariant?.id ?? "")")
                                .id("\(usdz)-\(selectedVariant?.id ?? "")") // variant almashsa tugma qayta yaratiladi
                            } else if activeModel3d?.glbUrl != nil {
                                Text("🧊 \(locale.t("product_3d_ios_note"))")
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Stepper("\(locale.t("product_qty_label")): \(quantity)", value: $quantity, in: 1...50)

                            DeliveryCardView(delivery: product.delivery)

                            if let price {
                                VStack(alignment: .leading) {
                                    Text(locale.t("product_approx_price")).font(.caption).foregroundStyle(Color.textSecondary)
                                    Text("\(String(format: "%.0f", price).formattedSom) so'm").font(.title3).bold()
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.brandPrimary.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if let variant = selectedVariant {
                                let qty = variant.availableQuantity ?? 0
                                if qty > 0 {
                                    HStack(spacing: 5) {
                                        Image(systemName: "shippingbox.fill").font(.caption)
                                        Text("\(qty) dona omborda mavjud").font(.caption).bold()
                                    }
                                    .padding(.horizontal, 11).padding(.vertical, 6)
                                    .background(Color.accent)
                                    .foregroundStyle(Color.onAccent)
                                    .clipShape(Capsule())
                                } else {
                                    Text(locale.t("product_out_of_stock"))
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }

                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(Color.appError).font(.caption)
                            }

                            Button {
                                if auth.isAuthenticated { showOrderSheet = true }
                                else { errorMessage = locale.t("checkout_login_required") }
                            } label: {
                                Text("📦 \(locale.t("cart_submit"))")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(price == nil ? Color.disabledBackground : Color.brand)
                                    .foregroundStyle(price == nil ? Color.textDisabled : Color.onBrand)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(price == nil)

                            Button {
                                guard let variant = selectedVariant else { return }
                                cart.addProduct(product, variant: variant)
                                addedToCart = true
                            } label: {
                                Label(locale.t("product_add_to_cart"), systemImage: "cart.badge.plus")
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
        .alert(locale.t("product_added_alert_title"), isPresented: $addedToCart) {
            Button("OK") {}
        }
        .onChange(of: selectedVariant?.id) { _, _ in
            guard let v = selectedVariant else { return }
            galleryIndex = 0 // variant almashganda galereya shu variant rasmlariga o'tadi
            width = v.width
            height = v.height
            depth = v.depth
        }
        .fullScreenCover(isPresented: $showAR) {
            if let urlString = activeModel3d?.usdzUrl, let url = URL(string: urlString) {
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
        let urls = product.galleryUrls(for: selectedVariant)
        Group {
            if urls.count > 1 {
                TabView(selection: $galleryIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { i, url in
                        galleryImage(url).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottom) {
                    // Standart nuqtalar och fonda ko'rinmaydi — brend rangida o'zimiznikini chizamiz.
                    HStack(spacing: 6) {
                        ForEach(0..<urls.count, id: \.self) { i in
                            Capsule()
                                .fill(i == galleryIndex ? Color.brand : Color.appBorder)
                                .frame(width: i == galleryIndex ? 18 : 6, height: 6)
                        }
                    }
                    .padding(.bottom, 10)
                    .animation(.easeOut(duration: 0.2), value: galleryIndex)
                    .allowsHitTesting(false)
                }
            } else {
                galleryImage(urls.first ?? "")
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !urls.isEmpty { showGallery = true } }
        .fullScreenCover(isPresented: $showGallery) {
            ImageGalleryView(
                urls: urls, index: $galleryIndex,
                errorText: locale.t("gallery_image_error"),
                closeLabel: locale.t("common_close")
            )
        }
    }

    /// Rasm kesilmaydi (`fit`): kvadrat kadrda butun mebel ko'rinadi.
    private func galleryImage(_ url: String) -> some View {
        ZStack {
            Color.appBackground
            CachedAsyncImage(url: URL(string: url)) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    Color.clear
                }
            }
        }
    }

private func load() async {
        do {
            let p: Product = try await APIClient.shared.getCached(
                "/products/\(productId)/", auth: true,
                onRefresh: { fresh in
                    // Server o'zgartirgan bo'lsa jim yangilanadi; tanlangan variant saqlanadi.
                    product = fresh
                    if let current = selectedVariant,
                       let same = fresh.variants.first(where: { $0.id == current.id }) {
                        selectedVariant = same
                    } else {
                        selectedVariant = fresh.variants.first
                    }
                }
            )
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
