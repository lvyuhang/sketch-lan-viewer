import SwiftUI

struct ConnectView: View {
    @ObservedObject var client: MirrorClient
    var onConnected: () -> Void

    @State private var serverText: String = ""
    @State private var mode: ConnectMode = .wifi
    @FocusState private var focused: Bool

    enum ConnectMode {
        case wifi
        case usb
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("览LAN")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Text("把 Sketch 选中的画板全屏扔到手机上。\nMac 上先开「插件 ▸ 览LAN ▸ 开启预览」。")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer().frame(height: 28)

            modePicker
                .padding(.horizontal, 24)

            Spacer().frame(height: 20)

            if mode == .wifi {
                wifiForm
            } else {
                usbForm
            }

            if let err = client.lastError, client.state != .online {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4))
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            VStack(spacing: 12) {
                statusRow

                Button(action: primaryAction) {
                    HStack {
                        if case .connecting = client.state {
                            ProgressView()
                                .tint(.black)
                        }
                        Text(connectButtonTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isConnectDisabled)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .onAppear {
            if serverText.isEmpty {
                serverText = client.savedServerURL
            }
            if client.state == .online {
                onConnected()
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

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeTab(title: "Wi‑Fi", selected: mode == .wifi) { mode = .wifi }
            modeTab(title: "USB 线", selected: mode == .usb) { mode = .usb }
        }
        .padding(4)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func modeTab(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.white : Color.clear)
                .foregroundStyle(selected ? Color.black : Color(white: 0.55))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var wifiForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mac 地址")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(white: 0.55))

            TextField("http://192.168.x.x:9777", text: $serverText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
                .focused($focused)
                .onSubmit { connectWiFi() }

            Text("在 Mac 浏览器打开扫码页也能看到地址：\nhttp://本机IP:9777/qr")
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
    }

    private var usbForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("USB 连接")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(white: 0.55))

            Text("1. Mac 上 Sketch 已「开启预览」\n2. Mac 上跑着 LanUSBHelper（USB 助手）\n3. 用数据线插上这台 iPhone（信任电脑）\n4. 点下面「USB 连接」——不用同一 Wi‑Fi")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.7))
                .fixedSize(horizontal: false, vertical: true)

            Text("原理：手机本地 127.0.0.1:9777 经 Peertalk 反向转到 Mac 览LAN。不是 iproxy，也不用越狱。")
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectButtonTitle: String {
        if case .connecting = client.state { return "连接中…" }
        return mode == .usb ? "USB 连接" : "连接"
    }

    private var isConnectDisabled: Bool {
        if case .connecting = client.state { return true }
        if mode == .wifi {
            return serverText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(client.state.label)
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.6))
            Spacer()
        }
    }

    private var statusColor: Color {
        switch client.state {
        case .online: return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .connecting: return Color(red: 1, green: 0.8, blue: 0)
        case .offline: return Color(red: 1, green: 0.27, blue: 0.23)
        case .idle: return Color(white: 0.4)
        }
    }

    private func primaryAction() {
        if mode == .usb {
            connectUSB()
        } else {
            connectWiFi()
        }
    }

    private func connectWiFi() {
        focused = false
        USBTunnel.shared.stop()
        client.connect(to: serverText, transport: .wifi)
    }

    private func connectUSB() {
        focused = false
        USBTunnel.shared.start()
        // Give the local proxy a tick to bind before MirrorClient probes /health.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            client.connect(to: USBTunnel.proxyURL, transport: .usb)
        }
    }
}
