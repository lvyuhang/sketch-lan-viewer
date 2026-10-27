import Foundation

/// Starts the on-device reverse proxy used for USB mode.
///
/// Flow (no jailbreak):
/// 1. Listen on iPhone `127.0.0.1:9777` + Peertalk mux port `19777`.
/// 2. Mac `LanUSBHelper` attaches over USB (usbmuxd → Peertalk) and relays
///    each socket to Mac localhost 览LAN.
/// 3. `MirrorClient` connects to `http://127.0.0.1:9777`.
///
/// Stock `iproxy` only does Mac→device; this is the Flipper/Peertalk reverse path.
@MainActor
final class USBTunnel {
    static let shared = USBTunnel()

    static let proxyURL = "http://127.0.0.1:9777"
    static let muxPort = 19777
    static let proxyPort = 9777

    private let host = USBTunnelHost()
    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        host.start(withProxyPort: UInt(Self.proxyPort), muxPort: UInt(Self.muxPort))
        isRunning = true
    }

    func stop() {
        host.stop()
        isRunning = false
    }
}
