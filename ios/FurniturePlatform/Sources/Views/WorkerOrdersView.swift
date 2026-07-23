import SwiftUI

/// Usta: o'z firmasi buyurtmalari — statusni o'zgartiradi va o'ziga tegishli
/// ishlab chiqarish bosqichlarini bajaradi (progress/complete). Android
/// (`WorkerOrdersScreen`) bilan bir xil qamrov — hozircha rasm yuklash yo'q,
/// faqat matnli izoh.
struct WorkerOrdersView: View {
    @State private var orders: [Order] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).padding()
                } else if orders.isEmpty {
                    Text("Buyurtmalar yo'q").foregroundStyle(.secondary)
                } else {
                    List(orders) { order in
                        OrderCardView(order: order, onChanged: { Task { await load() } })
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Buyurtmalar")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let page: Paginated<Order> = try await APIClient.shared.get("/orders/", auth: true)
            orders = page.results
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct OrderCardView: View {
    let order: Order
    let onChanged: () -> Void

    @State private var expanded = false
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.phone).bold()
                Spacer()
                Text(order.statusDisplay).font(.caption)
            }
            Text(order.address).font(.caption).foregroundStyle(.secondary)
            Text("\(order.totalPrice.formattedSom) so'm").bold()

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(nextOrderStatus[order.status] ?? [], id: \.self) { s in
                        Button {
                            Task { await setStatus(s) }
                        } label: {
                            Text(orderStatusLabel[s] ?? s)
                                .font(.caption)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(s == "cancelled" ? Color.red.opacity(0.12) : Color(.secondarySystemBackground))
                                .foregroundStyle(s == "cancelled" ? .red : .primary)
                                .clipShape(Capsule())
                        }
                        .disabled(busy)
                    }
                    if !order.workflowSteps.isEmpty {
                        Button {
                            expanded.toggle()
                        } label: {
                            Label("Ishlab chiqarish (\(order.progressPercent ?? 0)%)", systemImage: "hammer.fill")
                                .font(.caption)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.brandPrimary.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if expanded {
                ForEach(order.workflowSteps) { step in
                    StepRowView(step: step, onChanged: onChanged)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func setStatus(_ status: String) async {
        busy = true
        errorMessage = nil
        struct Body: Encodable { let status: String }
        do {
            let _: Order = try await APIClient.shared.post("/orders/\(order.id)/set_status/", body: Body(status: status))
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        busy = false
    }
}

private struct StepRowView: View {
    let step: WorkflowStepInstance
    let onChanged: () -> Void

    @State private var showSheet = false
    @State private var completing = false

    private var canAct: Bool {
        step.status != "completed" && (step.status == "in_progress" || step.isAvailable)
    }

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading) {
                Text(step.name).font(.subheadline)
                Text("\(step.roleDisplay ?? "") · \(step.statusDisplay)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if canAct {
                Button("Yangilash") { completing = false; showSheet = true }.font(.caption)
                Button("Yakunlash") { completing = true; showSheet = true }.font(.caption).bold()
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showSheet) {
            StepUpdateSheet(step: step, isCompletion: completing, onDone: onChanged)
        }
    }

    private var icon: String {
        switch step.status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "arrow.triangle.2.circlepath"
        default: return "circle"
        }
    }

    private var color: Color {
        switch step.status {
        case "completed": return .green
        case "in_progress": return .blue
        default: return .secondary
        }
    }
}

private struct StepUpdateSheet: View {
    let step: WorkflowStepInstance
    let isCompletion: Bool
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(isCompletion ? "Bosqichni yakunlash" : "Yangilanish qo'shish") {
                    TextField("Izoh (ixtiyoriy)", text: $comment, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(step.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "..." : "Yuborish") { Task { await submit() } }.disabled(busy)
                }
            }
        }
    }

    private func submit() async {
        busy = true
        errorMessage = nil
        struct Body: Encodable { let comment: String }
        do {
            let _: WorkflowStepInstance = try await APIClient.shared.post(
                "/workflow-instances/\(step.id)/\(isCompletion ? "complete" : "progress")/",
                body: Body(comment: comment)
            )
            onDone()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        busy = false
    }
}
