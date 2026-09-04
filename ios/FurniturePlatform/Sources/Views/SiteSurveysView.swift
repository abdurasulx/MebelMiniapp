import SwiftUI

private let statusColor: [String: Color] = [
    "assigned": .gray,
    "visited": .orange,
    "order_created": .green,
    "cancelled": .red,
]

/// Ustaga tayinlangan "joy o'rganish" (site survey) topshiriqlari ro'yxati
/// (qarang backend apps.custom_orders.SiteSurvey).
struct SiteSurveysView: View {
    @State private var surveys: [SiteSurvey] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).padding()
                } else if surveys.isEmpty {
                    Text("Hali tayinlangan joy yo'q").foregroundStyle(.secondary)
                } else {
                    List(surveys) { s in
                        NavigationLink(destination: SiteSurveyDetailView(surveyId: s.id, onChanged: { Task { await load() } })) {
                            HStack {
                                Circle().fill(statusColor[s.status] ?? .gray).frame(width: 10, height: 10)
                                VStack(alignment: .leading) {
                                    Text(s.address.isEmpty ? "Manzil ko'rsatilmagan" : s.address).bold()
                                    Text("\(s.customerName ?? "Mijoz") · \(s.statusDisplay)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Joy o'rganish")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let page: Paginated<SiteSurvey> = try await APIClient.shared.get("/site-surveys/", auth: true)
            surveys = page.results
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
