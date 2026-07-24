import SwiftUI

/// Professional ko'rinishdagi N-katakli SMS-kod kiritish maydoni. Haqiqiy
/// kiritish yagona (ko'rinmas) `TextField` orqali amalga oshadi — bu
/// klaviatura/fokus muammolarisiz eng ishonchli yondashuv. Flutter'dagi
/// `lib/widgets/otp_box_input.dart` bilan bir xil.
struct OtpBoxInput: View {
    @Binding var code: String
    let length: Int
    var onCompleted: ((String) -> Void)?

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { i in
                    box(i)
                }
            }
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .focused($focused)
                .opacity(0.01)
                .accessibilityIdentifier("otpCodeField")
                .onChange(of: code) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    code = String(digits.prefix(length))
                    if code.count == length { onCompleted?(code) }
                }
        }
        .frame(height: 56)
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }

    private func box(_ index: Int) -> some View {
        let chars = Array(code)
        let char = index < chars.count ? String(chars[index]) : ""
        let isActive = index == chars.count
        return Text(char)
            .font(.system(size: 22, weight: .heavy))
            .frame(width: 44, height: 52)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.brandDeep : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
