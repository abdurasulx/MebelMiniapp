import UIKit

extension UIApplication {
    /// Google Sign-In kabi SDK'lar modal oynani ko'rsatish uchun `UIViewController`
    /// talab qiladi — SwiftUI'da bevosita bunday obyekt yo'q, shuning uchun faol
    /// oyna (`UIWindowScene`)ning root controller'idan olinadi.
    static var topViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
