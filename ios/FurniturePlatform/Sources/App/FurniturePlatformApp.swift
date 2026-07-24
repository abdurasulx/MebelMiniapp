import SwiftUI

@main
struct FurniturePlatformApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var likes = LikesStore()
    @StateObject private var location = LocationStore()
    @StateObject private var cart = CartStore()
    @StateObject private var locale = LocaleStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(likes)
                .environmentObject(location)
                .environmentObject(cart)
                .environmentObject(locale)
                .task {
                    location.bootstrap()
                    cart.load()
                }
        }
    }
}
