import SwiftUI

struct RootView: View {
    @StateObject private var client = MirrorClient()
    @State private var showConnect = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showConnect {
                ConnectView(client: client) {
                    showConnect = false
                }
            } else {
                PreviewView(client: client) {
                    client.disconnect(reconnect: false)
                    USBTunnel.shared.stop()
                    showConnect = true
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
