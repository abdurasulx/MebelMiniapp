import SwiftUI

/// Faqat ko'rish uchun ombor ro'yxati — boshqaruv (kirim/chiqim, varaq
/// kirim qilish, material qo'shish) hozircha faqat veb-portalda.
struct WarehousesView: View {
    @EnvironmentObject private var locale: LocaleStore
    @State private var warehouses: [Warehouse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false

    var body: some View {
        // DIQQAT: WorkerHomeView'ning NavigationStack'i ichidan NavigationLink
        // orqali ochiladi — shuning uchun bu yerda YANA NavigationStack
        // o'ralmaydi (ichma-ich NavigationStack ichidagi NavigationLink
        // jimgina ishlamay qoladi — qarang LoyihalarimView'dagi bir xil izoh).
        Group {
            if isOffline && warehouses.isEmpty && !isLoading {
                OfflineView(onRetry: { Task { await load() } })
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(Color.appError).padding()
            } else if warehouses.isEmpty {
                Text(locale.t("warehouses_empty")).foregroundStyle(Color.textSecondary)
            } else {
                List(warehouses) { w in
                    NavigationLink(destination: WarehouseDetailView(warehouse: w)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name).bold()
                            Text("\(w.kindDisplay) · \(w.address)").font(.caption).foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(locale.t("worker_warehouses_tooltip"))
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        isOffline = false
        do {
            let result: Paginated<Warehouse> = try await APIClient.shared.get("/warehouses/", auth: true)
            warehouses = result.results
        } catch {
            if OfflineView.isOffline(error) {
                isOffline = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

struct WarehouseDetailView: View {

    @EnvironmentObject private var locale: LocaleStore
    let warehouse: Warehouse

    @State private var stocks: [MaterialStock] = []
    @State private var remnants: [MaterialRemnantItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false

    private var isRawMaterial: Bool { warehouse.kind == "raw_material" }

    var body: some View {
        Group {
            if isOffline && !isLoading {
                OfflineView(onRetry: { Task { await load() } })
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(Color.appError).padding()
            } else if !isRawMaterial {
                Text(locale.t("warehouse_ready_goods_note"))
                    .foregroundStyle(Color.textSecondary).multilineTextAlignment(.center).padding()
            } else {
                List {
                    Section(locale.t("warehouse_stocks")) {
                        if stocks.isEmpty {
                            Text(locale.t("warehouse_no_stocks")).font(.caption).foregroundStyle(Color.textSecondary)
                        }
                        ForEach(stocks) { s in
                            HStack {
                                Text(s.materialName)
                                Spacer()
                                Text("\(s.quantity.formattedSom) \(s.materialUnit)").foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                    Section(locale.t("warehouse_offcuts_sheets")) {
                        if remnants.isEmpty {
                            Text(locale.t("warehouse_no_offcuts")).font(.caption).foregroundStyle(Color.textSecondary)
                        }
                        ForEach(remnants) { r in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.materialName)
                                    if let width = r.width {
                                        Text("\(width.formattedSom) x \(r.length.formattedSom) \(r.materialUnit)")
                                            .font(.caption2).foregroundStyle(Color.textSecondary)
                                    } else {
                                        Text("\(r.length.formattedSom) \(r.materialUnit)")
                                            .font(.caption2).foregroundStyle(Color.textSecondary)
                                    }
                                }
                                Spacer()
                                Text("x\(r.quantity)").foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle(warehouse.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard isRawMaterial else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        isOffline = false
        do {
            async let stocksResult: Paginated<MaterialStock> = APIClient.shared.get(
                "/warehouses/\(warehouse.id)/material-stocks/", auth: true
            )
            async let remnantsResult: Paginated<MaterialRemnantItem> = APIClient.shared.get(
                "/warehouses/\(warehouse.id)/material-remnants/", auth: true
            )
            let (s, r) = try await (stocksResult, remnantsResult)
            stocks = s.results
            remnants = r.results
        } catch {
            if OfflineView.isOffline(error) {
                isOffline = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}
