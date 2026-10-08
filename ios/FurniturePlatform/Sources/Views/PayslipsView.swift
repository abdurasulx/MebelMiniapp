import SwiftUI

private let monthNames = [
    "Yanvar", "Fevral", "Mart", "Aprel", "May", "Iyun",
    "Iyul", "Avgust", "Sentabr", "Oktabr", "Noyabr", "Dekabr",
]

private func periodLabel(_ period: String) -> String {
    let parts = period.split(separator: "-")
    guard parts.count >= 2, let m = Int(parts[1]), m >= 1, m <= 12 else { return period }
    return "\(monthNames[m - 1]) \(parts[0])"
}

/// To'lov turiga mos asosiy summa tavsifi — web'dagi `payBreakdown()`
/// (FirmaPayroll.jsx) bilan bir xil.
private func payBreakdown(_ p: Payslip) -> String {
    switch p.payType {
    case "fixed":
        return "\(p.baseSalary.formattedSom) so'm/oy"
    case "fixed_bonus":
        return "MAX(\(p.baseSalary.formattedSom) oylik, \(p.completedTasksAmount.formattedSom) bajarilgan ish)"
    case "commission":
        return "\(p.commissionSales.formattedSom) so'mdan \(p.commissionAmount.formattedSom) so'm"
    case "hourly":
        let hours = Double(p.workedHours) ?? 0
        let amount = Double(p.hourlyAmount) ?? 0
        let perHour = hours > 0 ? amount / hours : 0
        return "\(p.workedHours.formattedSom) soat × \(String(format: "%.0f", perHour).formattedSom)"
    case "piecework":
        return "\(p.completedTasksAmount.formattedSom) so'm (bajarilgan ishlar)"
    default:
        return "—"
    }
}

/// Xodimning o'z oylik ish haqi ro'yxati — web'dagi `MyPayslips`
/// (FirmaPayroll.jsx) bilan bir xil ko'rinish.
struct PayslipsView: View {
    @State private var payslips: [Payslip] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false

    var body: some View {
        // DIQQAT: bu View endi AccountView'ning NavigationStack'i ichidan
        // NavigationLink orqali ochiladi — shuning uchun bu yerda YANA
        // NavigationStack o'ralmaydi (qarang LoyihalarimView/WarehousesView'dagi
        // bir xil izoh — ichma-ich NavigationStack NavigationLink'larni
        // jimgina ishlamay qoldiradi).
        Group {
            if isOffline && payslips.isEmpty && !isLoading {
                OfflineView(onRetry: { Task { await load() } })
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(Color.appError).padding()
            } else if payslips.isEmpty {
                Text("Hali hisoblangan oylik yo'q.").foregroundStyle(Color.textSecondary)
            } else {
                List(payslips) { p in
                    PayslipRow(payslip: p)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Ish haqim")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        isOffline = false
        do {
            let result: Paginated<Payslip> = try await APIClient.shared.get("/payslips/", auth: true)
            payslips = result.results
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

private struct PayslipRow: View {
    let payslip: Payslip

    @State private var expanded = false
    @State private var payments: [PayslipPayment]?
    @State private var loading = false
    @State private var errorMessage: String?

    private var extras: String {
        var text = "\(payslip.payTypeDisplay) · \(payBreakdown(payslip))"
        if payslip.payType == "commission", let workflow = Double(payslip.workflowEarnings), workflow > 0 {
            text += " + \(payslip.workflowEarnings.formattedSom) workflow"
        }
        if let kpi = Double(payslip.kpiBonusAmount), kpi > 0 {
            text += " + \(payslip.kpiBonusAmount.formattedSom) KPI bonus"
        }
        return text
    }

    private var paidTotal: Double { Double(payslip.paidTotal ?? "") ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodLabel(payslip.period)).bold()
                    Text(extras).font(.caption).foregroundStyle(Color.textSecondary)
                    if !payslip.isPaid && paidTotal > 0 {
                        Text("\(String(format: "%.0f", paidTotal).formattedSom) avans olingan")
                            .font(.caption2).foregroundStyle(Color.textDisabled)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(payslip.totalAmount.formattedSom) so'm").bold()
                    Text(payslip.isPaid ? "To'landi" : "Kutilmoqda")
                        .font(.caption2)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(payslip.isPaid ? Color.appSuccess.opacity(0.15) : Color.appWarning.opacity(0.15))
                        .foregroundStyle(payslip.isPaid ? .green : .orange)
                        .clipShape(Capsule())
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(Color.textDisabled)
                }
            }
            if expanded {
                Divider().padding(.vertical, 10)
                if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(Color.appError)
                } else if (payments ?? []).isEmpty {
                    Text("Hali to'lov qilinmagan.").font(.caption).foregroundStyle(Color.textSecondary)
                } else {
                    ForEach(payments ?? []) { pm in
                        HStack(alignment: .top) {
                            Text("\(pm.kindDisplay) — \(pm.amount.formattedSom) so'm"
                                + ((pm.note ?? "").isEmpty ? "" : " (\(pm.note ?? ""))"))
                                .font(.caption)
                            Spacer()
                            Text(pm.paidAt).font(.caption2).foregroundStyle(Color.textDisabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { toggle() }
    }

    private func toggle() {
        withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
        guard expanded, payments == nil, !loading else { return }
        loading = true
        errorMessage = nil
        Task {
            do {
                let list: [PayslipPayment] = try await APIClient.shared.get(
                    "/payslips/\(payslip.id)/payments/", auth: true
                )
                payments = list
            } catch {
                errorMessage = error.localizedDescription
            }
            loading = false
        }
    }
}
