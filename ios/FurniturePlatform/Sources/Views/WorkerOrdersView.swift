import SwiftUI

/// Xodim (ustadan tortib sotuvchi/haydovchigacha) — o'z firmasi
/// buyurtmalarini boshqaradi (status: qabul qilish/yetkazish) VA faqat
/// o'ziga biriktirilgan ishlab chiqarish bosqichlarini bajaradi
/// (progress/complete). Ikkinchisi `order.workflowSteps`dan EMAS (u
/// kompaniyaning barcha bosqichini qamrab oladi) — balki alohida
/// `/workflow-instances/`dan olinadi, chunki backend shu yerda xodimni
/// o'ziniki bo'lmagan bosqichlarni ko'rishdan avtomatik cheklaydi
/// (qarang apps/workflow/views.py get_queryset).
struct WorkerOrdersView: View {
    @State private var orders: [Order] = []
    @State private var myTasks: [WorkflowStepInstance] = []
    @State private var openTasks: [WorkflowStepInstance] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false

    private var manualTasks: [WorkflowStepInstance] { myTasks.filter { $0.order == nil } }

    private func mySteps(for order: Order) -> [WorkflowStepInstance] {
        myTasks.filter { $0.order == order.id }
    }

    /// Faqat MENING bosqichlarimdan kamida bittasi HOZIR harakat
    /// qilinadigan (navbatim kelgan yoki allaqachon boshlangan) bo'lsa
    /// buyurtma ro'yxatda ko'rinadi — bosqichim allaqachon bajarilgan/
    /// tasdiqlangan yoki hali boshqa ustaning navbatida bo'lsa yashiriladi.
    private func isActiveForMe(_ order: Order) -> Bool {
        mySteps(for: order).contains { $0.status == "in_progress" || ($0.status == "pending" && $0.isAvailable) }
    }

    private var activeOrders: [Order] { orders.filter(isActiveForMe) }

    var body: some View {
        NavigationStack {
            if isOffline && orders.isEmpty && myTasks.isEmpty && !isLoading {
                OfflineView(onRetry: { Task { await load() } })
                    .navigationTitle("Buyurtmalar")
            } else {
                Group {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).padding()
                    } else if activeOrders.isEmpty && manualTasks.isEmpty && openTasks.isEmpty {
                        Text("Hozircha vazifa yo'q").foregroundStyle(.secondary)
                    } else {
                        List {
                            if !openTasks.isEmpty {
                                Section {
                                    ForEach(openTasks) { step in
                                        OpenTaskRowView(step: step, onApplied: { await load() })
                                    }
                                } header: {
                                    Text("Erkin topshiriqlar")
                                } footer: {
                                    Text("Bu bosqichlarga hali usta biriktirilmagan — zayavka yuboring, firma egasi tasdiqlasa sizga o'tadi.")
                                }
                            }
                            if !manualTasks.isEmpty {
                                Section("Qo'shimcha vazifalar") {
                                    ForEach(manualTasks) { step in
                                        StepRowView(step: step, onChanged: { Task { await load() } })
                                    }
                                }
                            }
                            ForEach(activeOrders) { order in
                                OrderCardView(order: order, mySteps: mySteps(for: order), onChanged: { Task { await load() } })
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("Buyurtmalar")
                .task { await load() }
                .refreshable { await load() }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        isOffline = false
        do {
            async let ordersResult: Paginated<Order> = APIClient.shared.get("/orders/", auth: true)
            async let tasksResult: Paginated<WorkflowStepInstance> = APIClient.shared.get("/workflow-instances/", auth: true)
            async let openResult: Paginated<WorkflowStepInstance> = APIClient.shared.get("/workflow-instances/open/", auth: true)
            let (o, t, open) = try await (ordersResult, tasksResult, openResult)
            orders = o.results
            myTasks = t.results
            openTasks = open.results
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

private struct OrderCardView: View {
    let order: Order
    let mySteps: [WorkflowStepInstance]
    let onChanged: () -> Void

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
                    if !mySteps.isEmpty {
                        NavigationLink {
                            OrderStepsView(order: order, steps: mySteps, onChanged: onChanged)
                        } label: {
                            Label("Mening bosqichlarim (\(mySteps.count))", systemImage: "hammer.fill")
                                .font(.caption)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.brandPrimary.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
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

/// Buyurtmadagi (menga biriktirilgan) bosqichlar ro'yxati — avval
/// `OrderCardView` ichida joyida ("Mening bosqichlarim" tugmasi bosilganda)
/// ochilardi, endi alohida sahifada (qarang git tarixi: buyurtmalar
/// ro'yxati toza qolishi uchun so'ralgan o'zgarish).
private struct OrderStepsView: View {
    let order: Order
    let steps: [WorkflowStepInstance]
    let onChanged: () -> Void

    var body: some View {
        List {
            ForEach(steps) { step in
                StepRowView(step: step, onChanged: onChanged)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Buyurtma \(order.phone)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Xodimi hali biriktirilmagan ("erkin") bosqich — usta "Zayavka yuborish"ni
/// bosadi, firma egasi tasdiqlaguncha "Kutilmoqda" holatida turadi (qarang
/// FirmaProduction.jsx OpenPoolView bilan bir xil g'oya).
/// Xodimi hali yo'q ("erkin") bosqich — qatorga bosilganda alohida
/// sahifa ochiladi (`OpenTaskDetailView`), u yerda "Qabul qilish"
/// (zayavka) yoki "O'tkazib yuborish" tanlanadi. Avval bu yerning o'zida
/// to'g'ridan-to'g'ri tugma bo'lardi, endi ochiq tanlov aniqroq bo'lishi
/// uchun alohida sahifaga ko'chirildi.
private struct OpenTaskRowView: View {
    let step: WorkflowStepInstance
    let onApplied: () async -> Void

    private var content: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name).font(.subheadline)
                if let cuttingInstruction = step.cuttingInstruction {
                    Text(cuttingInstruction).font(.caption).fontWeight(.semibold).foregroundStyle(.teal)
                }
                Text(
                    [step.orderDisplay.map { "Buyurtma \($0)" }, step.roleDisplay]
                        .compactMap { $0 }.joined(separator: " · ")
                )
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if step.myApplicationStatus == "pending" {
                Text("Kutilmoqda")
                    .font(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    var body: some View {
        if step.myApplicationStatus == "pending" {
            content
        } else {
            NavigationLink {
                OpenTaskDetailView(step: step, onApplied: onApplied)
            } label: {
                content
            }
        }
    }
}

private struct OpenTaskDetailView: View {
    let step: WorkflowStepInstance
    let onApplied: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let cuttingInstruction = step.cuttingInstruction {
                Text(cuttingInstruction).font(.subheadline).fontWeight(.semibold).foregroundStyle(.teal)
            }
            Text(
                [step.orderDisplay.map { "Buyurtma \($0)" }, step.roleDisplay]
                    .compactMap { $0 }.joined(separator: " · ")
            )
            .foregroundStyle(.secondary)
            Spacer()
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }
            HStack(spacing: 12) {
                Button("O'tkazib yuborish") { dismiss() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(busy)
                Button {
                    Task { await apply() }
                } label: {
                    Group {
                        if busy { ProgressView() } else { Text("Qabul qilish") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
            }
        }
        .padding()
        .navigationTitle(step.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Firma egasi tasdiqlashini kutadi, darhol biriktirmaydi (qarang
    /// backend `apply`).
    private func apply() async {
        busy = true
        errorMessage = nil
        struct EmptyBody: Encodable {}
        do {
            let _: WorkflowStepInstance = try await APIClient.shared.post(
                "/workflow-instances/\(step.id)/apply/", body: EmptyBody(), auth: true
            )
            await onApplied()
            dismiss()
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
    @State private var starting = false

    // "Yangilash"/"Yakunlash" tugmalari faqat hali yakunlanmagan bosqichda
    // ko'rsatiladi — "Tasdiqlangan"/"Bekor qilindi" allaqachon yakuniy holat.
    private var canAct: Bool {
        !WorkflowStepInstance.terminalStatuses.contains(step.status) &&
            (step.status == "in_progress" || step.isAvailable)
    }

    // Faqat qo'lda qo'shilgan (manual) va hali kutilayotgan vazifalarga
    // aniq "Boshlash" (pending -> in_progress) tugmasi ko'rsatiladi — web'dagi
    // TaskCard.advance() bilan bir xil naqsh (FirmaProduction.jsx).
    private var canStart: Bool {
        (step.isManual ?? false) && step.status == "pending" && step.isAvailable
    }

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name).font(.subheadline)
                if let description = step.description, !description.isEmpty {
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
                if let cuttingInstruction = step.cuttingInstruction {
                    Text(cuttingInstruction).font(.caption).fontWeight(.semibold).foregroundStyle(.teal)
                } else if let workTypeName = step.workTypeName {
                    Text("\(step.quantity ?? "") \(step.workTypeUnitDisplay ?? "") × \(workTypeName)")
                        .font(.caption).foregroundStyle(.teal)
                }
                Text(subtitle).font(.caption2).foregroundStyle(step.isOverdue ? .red : .secondary)
            }
            Spacer()
            if canStart {
                Button(starting ? "..." : "Boshlash") { Task { await start() } }
                    .font(.caption)
                    .disabled(starting)
            } else if canAct {
                Button("Yangilash") { completing = false; showSheet = true }.font(.caption)
                Button("Yakunlash") { completing = true; showSheet = true }.font(.caption).bold()
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showSheet) {
            StepUpdateSheet(step: step, isCompletion: completing, onDone: onChanged)
        }
    }

    private func start() async {
        starting = true
        struct Body: Encodable { let status: String }
        do {
            let _: WorkflowStepInstance = try await APIClient.shared.patch(
                "/workflow-instances/\(step.id)/", body: Body(status: "in_progress")
            )
            onChanged()
        } catch {
            // Ro'yxat qayta yuklanganda holat baribir yangilanadi; xato bo'lsa jim o'tkazamiz.
        }
        starting = false
    }

    private var subtitle: String {
        var parts = [step.stageDisplay ?? "", step.roleDisplay ?? "", step.statusDisplay]
        if let deadline = step.deadline { parts.append("muddat: \(deadline)") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var icon: String {
        switch step.status {
        case "completed": return "checkmark.circle.fill"
        case "approved": return "checkmark.seal.fill"
        case "cancelled": return "xmark.circle.fill"
        case "in_progress": return "arrow.triangle.2.circlepath"
        default: return "circle"
        }
    }

    private var color: Color {
        switch step.status {
        case "completed": return .green
        case "approved": return .blue
        case "cancelled": return .red
        case "in_progress": return .orange
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

    @State private var photoData: Data?
    @State private var showCamera = false

    private var photoRequired: Bool { isCompletion && step.photoRequirement == "required" }
    private var commentRequired: Bool { isCompletion && step.commentRequirement == "required" }
    // Ogohlantirish/tugma-o'chirish faqat talab HALI QONDIRILMAGAN bo'lsa —
    // aks holda rasm/izoh allaqachon kiritilgandan keyin ham doimiy
    // "majburiy" deb ko'rsatilib, foydalanuvchini chalg'itardi (sinovda
    // aniqlangan haqiqiy muammo).
    private var photoMissing: Bool { photoRequired && photoData == nil }
    private var commentMissing: Bool { commentRequired && comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var canSubmit: Bool { !photoMissing && !commentMissing }

    var body: some View {
        NavigationStack {
            Form {
                Section(isCompletion ? "Bosqichni yakunlash" : "Yangilanish qo'shish") {
                    TextField(commentRequired ? "Izoh (majburiy)" : "Izoh (ixtiyoriy)", text: $comment, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    if commentMissing {
                        Text("Bu bosqichni yakunlash uchun izoh majburiy")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage).resizable().scaledToFit().frame(height: 160)
                    }
                    Button {
                        showCamera = true
                    } label: {
                        Label(photoData == nil ? "Kamerani ochish" : "Rasm olindi ✓", systemImage: "camera")
                    }
                } header: {
                    if photoMissing { Text("Bu bosqichni yakunlash uchun rasm majburiy") }
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
                    Button(busy ? "..." : "Yuborish") { Task { await submit() } }.disabled(busy || !canSubmit)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker { image in
                    photoData = image.jpegData(compressionQuality: 0.85)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func submit() async {
        if photoRequired && photoData == nil {
            errorMessage = "Bu bosqich uchun rasm majburiy"
            return
        }
        if commentRequired && comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Bu bosqich uchun izoh majburiy"
            return
        }
        busy = true
        errorMessage = nil
        let path = "/workflow-instances/\(step.id)/\(isCompletion ? "complete" : "progress")/"
        do {
            if let photoData {
                let _: WorkflowStepInstance = try await APIClient.shared.postMultipartImage(
                    path, imageData: photoData, fields: ["comment": comment], auth: true
                )
            } else {
                struct Body: Encodable { let comment: String }
                let _: WorkflowStepInstance = try await APIClient.shared.post(path, body: Body(comment: comment))
            }
            onDone()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        busy = false
    }
}
