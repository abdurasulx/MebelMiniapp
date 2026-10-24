import PhotosUI
import SwiftUI
import WebKit

struct ConversionsView: View {
    @ObservedObject var store: ConversionStore
    var measurement: FurnitureMeasurement?
    @AppStorage("converterServer") private var server = "http://100.90.116.106:5000"
    @State private var photo: PhotosPickerItem?
    @State private var jpeg: Data?
    @State private var width = ""
    @State private var height = ""
    @State private var depth = ""
    @State private var textured = true
    @State private var submitting = false
    @State private var loadingPhoto = false
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section("Yangi 3D model") {
                    TextField("Konvertor serveri", text: $server)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL).disabled(submitting)
                    Text("Telefon Tailscale orqali serverga ulangan bo‘lsin.")
                        .font(.caption).foregroundStyle(.secondary)
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label(jpeg == nil ? "Mebel rasmini tanlang" : "Rasmni almashtirish", systemImage: "photo")
                    }.disabled(submitting || loadingPhoto)
                    if loadingPhoto { ProgressView("Rasm ochilmoqda…") }
                    if let jpeg, let image = UIImage(data: jpeg) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                    }
                    dimensionField("Eni, sm", text: $width)
                    dimensionField("Balandligi, sm", text: $height)
                    dimensionField("Chuqurligi, sm", text: $depth)
                    if let measurement {
                        Button("Skan o‘lchamlarini olish (taxminiy)") {
                            width = String(format: "%.1f", measurement.widthCentimeters)
                            height = String(format: "%.1f", measurement.heightCentimeters)
                            depth = String(format: "%.1f", measurement.depthCentimeters)
                        }.disabled(submitting)
                    }
                    Text("O‘lchamlarni tekshiring. Bo‘sh maydonni AI taxmin qiladi; LiDAR natijasi ham hozir taxminiy. Model proporsiyasi saqlanadi, eni va chuqurligi farq qilishi mumkin.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Tekstura bilan", isOn: $textured).disabled(submitting)
                    Button {
                        Task { await submit() }
                    } label: {
                        if submitting { ProgressView("Yuborilmoqda…") }
                        else { Label("3D yaratish", systemImage: "cube.transparent") }
                    }.disabled(jpeg == nil || submitting || loadingPhoto)
                    if let error { Text(error).foregroundStyle(.red) }
                }
                Section("Mening so‘rovlarim") {
                    if let message = store.storageError { Text(message).foregroundStyle(.red) }
                    if let message = store.connectionError {
                        Text("Yangilash amalga oshmadi: \(message). Saqlangan holat ko‘rsatilmoqda.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if store.jobs.isEmpty {
                        Text("Yuborilgan so‘rovlar va GLB natijalari shu yerda ko‘rinadi.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.jobs) { job in
                        NavigationLink { ConversionDetailView(store: store, id: job.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(job.title, systemImage: job.status == "done" ? "checkmark.circle.fill" : "cube")
                                    Spacer()
                                    Text("\(Int(job.percent))%" ).monospacedDigit()
                                }
                                Text(job.created.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                                if job.isActive { ProgressView(value: job.percent, total: 100) }
                                Text(job.stage).font(.caption)
                                if let position = job.position, position > 0 {
                                    Text("Navbat: \(position)").font(.caption)
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("3D so‘rovlar")
            .refreshable { await store.refresh() }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    await store.refresh()
                    do { try await Task.sleep(for: .seconds(4)) } catch { return }
                }
            }
            .onChange(of: photo) { _, item in
                jpeg = nil; loadingPhoto = true
                Task {
                    defer { loadingPhoto = false }
                    do {
                        guard let data = try await item?.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { throw ConversionError.message("Rasm ochilmadi.") }
                        // Bound upload memory and pixel count; normalize orientation through rendering.
                        let ratio = min(1, 2048 / max(image.size.width, image.size.height))
                        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in
                            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
                            image.draw(in: CGRect(origin: .zero, size: size))
                        }
                        guard let output = normalized.jpegData(compressionQuality: 0.9) else {
                            throw ConversionError.message("Rasmni tayyorlab bo‘lmadi.")
                        }
                        jpeg = output; error = nil
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
    }

    private func dimensionField(_ title: String, text: Binding<String>) -> some View {
        HStack { Text(title); TextField("AI taxmini", text: text).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
            .disabled(submitting)
    }

    private func submit() async {
        guard let jpeg else { return }
        submitting = true; error = nil
        defer { submitting = false }
        do {
            var dimensions: [String: Double] = [:]
            for (key, text) in [("width_cm", width), ("height_cm", height), ("depth_cm", depth)] {
                let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    guard let number = Double(value.replacingOccurrences(of: ",", with: ".")),
                          number.isFinite, number > 0, number <= 5000 else {
                        throw ConversionError.message("O‘lcham 0 dan katta va 5000 sm dan oshmasin.")
                    }
                    dimensions[key] = number
                }
            }
            try await store.submit(jpeg: jpeg, server: server, dimensions: dimensions, textured: textured)
        } catch { self.error = error.localizedDescription }
    }
}

private struct ConversionDetailView: View {
    @ObservedObject var store: ConversionStore
    let id: UUID
    @State private var file: URL?
    @State private var downloading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            if let job = store.jobs.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(job.title).font(.title2.bold())
                    Text(job.created.formatted())
                    Text(job.stage)
                    ProgressView(value: job.percent, total: 100)
                    Text("\(Int(job.percent))% — bosqich progressi taxminiy bo‘lishi mumkin.").font(.caption)
                    if let position = job.position, position > 0 { Text("Navbatdagi o‘rin: \(position)") }
                    if let message = job.error { Text(message).foregroundStyle(.red) }
                    if let note = job.note, !note.isEmpty { Text(note).font(.callout) }
                    if !job.inputDimensions.isEmpty {
                        Text("Yuborilgan o‘lchamlar: \(dimensionText(job.inputDimensions))").font(.callout)
                    }
                    if let dims = job.resultDimensions {
                        Text("GLB o‘lchamlari: \(dimensionText(dims))").font(.callout)
                    }
                    if job.status == "done", let url = job.resultURL {
                        Button("GLB modelni ochish", systemImage: "cube") { Task { await download(url) } }
                            .disabled(downloading)
                    }
                    if downloading { ProgressView("GLB yuklanmoqda…") }
                    if let error { Text(error).foregroundStyle(.red) }
                    if let file {
                        GLBPreview(file: file).frame(height: 380)
                        ShareLink("GLB faylni ulashish", item: file)
                    }
                    Button("Holatni yangilash", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                }.padding()
            }
        }.navigationTitle("So‘rov natijasi")
            .task { let cached = cacheURL; if FileManager.default.fileExists(atPath: cached.path) { file = cached } }
    }

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(id).glb")
    }

    private func dimensionText(_ dims: [String: Double]) -> String {
        [("Eni", "width_cm"), ("Balandligi", "height_cm"), ("Chuqurligi", "depth_cm")]
            .compactMap { label, key in dims[key].map { "\(label): \($0.centimeterText)" } }
            .joined(separator: ", ")
    }

    private func download(_ url: URL) async {
        downloading = true; error = nil
        defer { downloading = false }
        do {
            let (temporary, response) = try await URLSession.shared.download(from: url)
            defer { try? FileManager.default.removeItem(at: temporary) }
            try ConversionStore.check(response)
            let handle = try FileHandle(forReadingFrom: temporary)
            defer { try? handle.close() }
            guard try handle.read(upToCount: 4) == Data("glTF".utf8) else {
                throw ConversionError.message("Server GLB fayl qaytarmadi.")
            }
            if FileManager.default.fileExists(atPath: cacheURL.path) { try FileManager.default.removeItem(at: cacheURL) }
            try FileManager.default.copyItem(at: temporary, to: cacheURL)
            file = cacheURL
        } catch { self.error = error.localizedDescription }
    }
}

private struct GLBPreview: UIViewRepresentable {
    let file: URL
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.isOpaque = false
        do {
            guard let scriptURL = Bundle.main.url(forResource: "model-viewer.min", withExtension: "js") else {
                throw ConversionError.message("3D viewer resursi topilmadi.")
            }
            let script = try String(contentsOf: scriptURL, encoding: .utf8)
            let model = try Data(contentsOf: file).base64EncodedString()
            view.loadHTMLString("""
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <style>body{margin:0;background:#f3f5f4;font:16px system-ui}model-viewer{width:100%;height:100vh}#status{position:absolute;top:12px;left:12px}</style>
            <model-viewer camera-controls loading="eager" alt="Mebel 3D modeli"></model-viewer><div id="status">Model ochilmoqda…</div>
            <script type="module">\(script)
            (() => {
            const v=document.querySelector('model-viewer'),s=document.querySelector('#status');
            v.addEventListener('load',()=>s.remove());
            v.addEventListener('error',()=>s.textContent='Modelni ochib bo‘lmadi. GLB faylni ulashib ko‘ring.');
            const bytes=Uint8Array.from(atob('\(model)'),c=>c.charCodeAt(0));
            v.src=URL.createObjectURL(new Blob([bytes],{type:'model/gltf-binary'}));
            })();
            </script>
            """, baseURL: nil)
        } catch { view.loadHTMLString("<p>3D modelni ochib bo‘lmadi.</p>", baseURL: nil) }
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
