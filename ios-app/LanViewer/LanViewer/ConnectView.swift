import SwiftUI

/// Connect screen — Notion / Linear quiet: typography, hairlines, one accent.
struct ConnectView: View {
    @ObservedObject var client: MirrorClient
    var onConnected: () -> Void

    @State private var serverText: String = ""
    @State private var mode: ConnectMode = .usb
    @FocusState private var focused: Bool

    enum ConnectMode: String, CaseIterable, Identifiable {
        case usb
        case wifi
        var id: String { rawValue }
        var title: String {
            switch self {
            case .usb: return "USB"
            case .wifi: return "Wi‑Fi"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(SV.lightHairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    modeRow
                    detail
                    if let err = client.lastError, client.state != .online {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(SV.bad)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            Divider().overlay(SV.lightHairline)
            bottomBar
        }
        .background(SV.lightBg.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear {
            if serverText.isEmpty {
                serverText = client.savedServerURL
            }
            if client.state == .online {
                onConnected()
            } else if mode == .usb {
                connectUSB()
            }
        }
        .onChange(of: client.state) { newValue in
            if newValue == .online {
                onConnected()
            }
        }
        .onChange(of: mode) { newMode in
            if newMode == .wifi {
                USBTunnel.shared.stop()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sketch View")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SV.lightText1)
                Text(heroSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(SV.lightText2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            statusChip
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private var modeRow: some View {
        HStack(spacing: 0) {
            ForEach(ConnectMode.allCases) { item in
                Button {
                    mode = item
                } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: mode == item ? .semibold : .regular))
                        .foregroundStyle(mode == item ? SV.lightText1 : SV.lightText2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(mode == item ? SV.lightSurface : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(mode == item ? SV.lightHairline : Color.clear, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0xF0F0F0))
        )
        .accessibilityLabel("连接方式")
    }

    @ViewBuilder
    private var detail: some View {
        if mode == .wifi {
            wifiFields
        } else {
            usbHelp
        }
    }

    private var wifiFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mac 地址")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SV.lightText2)

            TextField("http://192.168.x.x:9777", text: $serverText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(SV.lightText1)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SV.lightSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(SV.lightHairline, lineWidth: 1)
                        )
                )
                .focused($focused)
                .onSubmit { connectWiFi() }

            Text("也可在 Mac 打开 http://本机IP:9777/qr")
                .font(.system(size: 12))
                .foregroundStyle(SV.lightText3)
        }
    }

    private var usbHelp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("用数据线连接")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SV.lightText1)
            Text("插上线，确认 Mac 上 LanUSBHelper 在跑。连上后，Sketch 选中画板即预览；左右滑切换同页画板。")
                .font(.system(size: 13))
                .foregroundStyle(SV.lightText2)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    if case .connecting = client.state {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(connectButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isConnectDisabled ? SV.accent.opacity(0.45) : SV.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isConnectDisabled)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(SV.lightBg)
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusDot)
                .frame(width: 6, height: 6)
            Text(client.state.label)
                .font(.system(size: 12))
                .foregroundStyle(SV.lightText2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .stroke(SV.lightHairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Copy / state

    private var heroSubtitle: String {
        switch mode {
        case .usb: return "经 USB 连 Mac 上的览LAN"
        case .wifi: return "与 Mac 同一 Wi‑Fi"
        }
    }

    private var connectButtonTitle: String {
        if case .connecting = client.state { return "正在连接…" }
        return mode == .usb ? "USB 连接" : "连接"
    }

    private var isConnectDisabled: Bool {
        if case .connecting = client.state { return true }
        if mode == .wifi {
            return serverText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private var statusDot: Color {
        switch client.state {
        case .online: return SV.ok
        case .connecting: return SV.warn
        case .offline: return SV.bad
        case .idle: return SV.lightText3
        }
    }

    // MARK: - Actions

    private func primaryAction() {
        if mode == .usb { connectUSB() } else { connectWiFi() }
    }

    private func connectWiFi() {
        focused = false
        USBTunnel.shared.stop()
        client.connect(to: serverText, transport: .wifi)
    }

    private func connectUSB() {
        focused = false
        USBTunnel.shared.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            client.connect(to: USBTunnel.proxyURL, transport: .usb)
        }
    }
}
