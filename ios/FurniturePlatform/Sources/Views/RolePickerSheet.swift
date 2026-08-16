import SwiftUI

/// Bir nechta kasbi bor xodim uchun — bugun qaysi rolda ishlashini tanlaydi
/// (web/Flutter'dagi RolePicker bilan bir xil vazifa).
struct RolePickerSheet: View {
    let positions: [String]
    let onPicked: (String) -> Void

    var body: some View {
        NavigationStack {
            List(positions, id: \.self) { p in
                let info = positionInfo(p)
                Button {
                    onPicked(p)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: info.systemImage).foregroundStyle(Color.brandDeep))
                        VStack(alignment: .leading) {
                            Text(info.label).bold()
                            Text(info.desc).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Bugun qaysi rolda ishlaysiz?")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
