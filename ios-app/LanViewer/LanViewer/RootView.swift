import SwiftUI

struct RootView: View {
    @StateObject private var client = MirrorClient()
    @State private var showConnect = true

    var body: some View {
        // No animated Group swap — avoids black blink between connect ↔ preview.
        ZStack {
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
    }
}
