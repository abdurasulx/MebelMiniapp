import SwiftUI

@main
struct FurniturePlatformApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var likes = LikesStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(likes)
        }
    }
}
