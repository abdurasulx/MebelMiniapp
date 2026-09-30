import GoogleSignIn
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PushManager.shared.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.setAPNsToken(deviceToken)
    }
}

@main
struct FurniturePlatformApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthStore()
    @StateObject private var likes = LikesStore()
    @StateObject private var location = LocationStore()
    @StateObject private var cart = CartStore()
    @StateObject private var locale = LocaleStore()
    @StateObject private var connectivity = ConnectivityStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(likes)
                .environmentObject(location)
                .environmentObject(cart)
                .environmentObject(locale)
                .environmentObject(connectivity)
                .task {
                    location.bootstrap()
                    cart.load()
                    // Splash paytida darhol chaqiriladi (qisqa timeout bilan)
                    // — oflayn holatini biror ekranning oddiy so'rovi 6s
                    // timeout bilan sekin aniqlashini kutmasdan.
                    await APIClient.shared.probeConnectivity()
                }
                // Google Sign-In oqimi tizim brauzeriga chiqib, natijani shu
                // URL orqali ilovaga qaytaradi — GoogleSignIn SDK shu yerda ushlab olishi kerak.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
