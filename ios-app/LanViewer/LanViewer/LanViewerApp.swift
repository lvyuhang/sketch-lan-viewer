import SwiftUI

@main
struct LanViewerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
