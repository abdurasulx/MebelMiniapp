import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

extension Notification.Name {
    /// FCM registration token olinganda/yangilanganda (AuthStore backend'ga qayta yuboradi).
    static let pushTokenUpdated = Notification.Name("pushTokenUpdated")
}

/// FCM/APNs push — backend `send_push()` (apps/notifications/push.py) FCM token
/// orqali yuboradi, shuning uchun iOS'da ham Firebase Messaging SDK kerak.
/// `GoogleService-Info.plist` hali loyihaga qo'shilmagan bo'lsa (Firebase
/// Console'da iOS ilova ro'yxatdan o'tkazilmagan) — push jim o'chiq turadi,
/// ilova xatosiz ishlayveradi.
final class PushManager: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = PushManager()

    private(set) var fcmToken: String?
    private var configured = false

    var isAvailable: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    func configure() {
        guard isAvailable, !configured else { return }
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        configured = true
    }

    /// Login bo'lgach chaqiriladi: ruxsat so'raydi va APNs'ga ro'yxatdan o'tadi.
    func requestAuthorizationAndRegister() {
        guard configured else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func setAPNsToken(_ deviceToken: Data) {
        guard configured else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        self.fcmToken = fcmToken
        NotificationCenter.default.post(name: .pushTokenUpdated, object: nil)
    }

    // Ilova ochiq turganda ham bannerni ko'rsatish.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
