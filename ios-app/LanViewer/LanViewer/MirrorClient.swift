import Foundation
import UIKit
import Combine

enum MirrorTransport: String {
    case wifi
    case usb
}

/// 对接览LAN / sketch-lan-mirror 本机中继：
/// - GET /health、/info、/current
/// - WebSocket `/`：文本 JSON meta，随后二进制 PNG
///
/// Wi‑Fi：连 Mac 局域网地址。
/// USB：连本机 `http://127.0.0.1:9777`（由 USBTunnel + Mac LanUSBHelper 反向转到 Mac 览LAN）。
@MainActor
final class MirrorClient: ObservableObject {
    @Published var state: ConnectionState = .idle
    @Published var image: UIImage?
    @Published var meta: FrameMeta?
    @Published var lastError: String?
    @Published var transport: MirrorTransport = .wifi

    private var session: URLSession?
    private var webSocket: URLSessionWebSocketTask?
    private var httpBase: URL?
    private var pendingMeta: FrameMeta?
    private var reconnectTask: Task<Void, Never>?
    private var receiveLoopRunning = false
    private var intentionalClose = false
    private var reconnectAttempt = 0

    private let defaultsKey = "lan.mirror.serverURL"
    private let transportKey = "lan.mirror.transport"

    var savedServerURL: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? "http://192.168.1.1:9777" }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    func connect(to raw: String, transport: MirrorTransport = .wifi) {
        disconnect(reconnect: false)
        self.transport = transport
        UserDefaults.standard.set(transport.rawValue, forKey: transportKey)

        guard let pair = MirrorURL.normalize(raw) else {
            state = .offline("地址格式不对")
            lastError = "请填类似 http://192.168.x.x:9777"
            return
        }
        if transport == .wifi {
            savedServerURL = pair.http.absoluteString
        }
        httpBase = pair.http
        intentionalClose = false
        reconnectAttempt = 0
        state = .connecting
        lastError = nil

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        self.session = session

        Task { [weak self] in
            await self?.probeAndOpen(http: pair.http, ws: pair.ws, session: session)
        }
    }

    func disconnect(reconnect: Bool) {
        intentionalClose = !reconnect
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveLoopRunning = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
        if !reconnect {
            state = .idle
            image = nil
            meta = nil
            lastError = nil
            if transport == .usb {
                USBTunnel.shared.stop()
            }
        }
    }

    func reconnectIfNeeded() {
        guard !intentionalClose else { return }
        let url = (transport == .usb) ? USBTunnel.proxyURL : savedServerURL
        scheduleReconnect(to: url)
    }

    // MARK: - Private

    private func probeAndOpen(http: URL, ws: URL, session: URLSession) async {
        let healthURL = http.appendingPathComponent("health")
        do {
            let (data, response) = try await session.data(from: healthURL)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                failAndRetry(transport == .usb
                    ? "USB 隧道通了，但览LAN 没响应——确认 Sketch 已「开启预览」，Mac 助手在跑"
                    : "中继没响应，确认 Sketch 里已「开启预览」")
                return
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = obj["ok"] as? Bool, !ok {
                failAndRetry("中继返回异常")
                return
            }
        } catch {
            failAndRetry(transport == .usb
                ? "USB 连不上：线插好了吗？Mac 助手开了吗？手机点过「信任」吗？"
                : "连不上 Mac（同 Wi-Fi？防火墙？地址对吗？）")
            return
        }

        await fetchCurrent(using: session, base: http)
        openWebSocket(ws: ws, session: session)
    }

    private func fetchCurrent(using session: URLSession, base: URL) async {
        let url = base.appendingPathComponent("current")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else { return }
            if let img = UIImage(data: data) {
                self.image = img
            }
        } catch {
            // 没有帧很正常，等 WebSocket
        }
    }

    private func openWebSocket(ws: URL, session: URLSession) {
        let task = session.webSocketTask(with: ws)
        self.webSocket = task
        receiveLoopRunning = true
        task.resume()
        state = .online
        reconnectAttempt = 0
        startReceiveLoop(task)
    }

    private func startReceiveLoop(_ task: URLSessionWebSocketTask) {
        Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.receiveLoopRunning, self.webSocket === task {
                do {
                    let message = try await task.receive()
                    await self.handle(message)
                } catch {
                    await MainActor.run {
                        self.handleSocketFailure(error)
                    }
                    break
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            if let m = FrameMeta.parse(from: text) {
                pendingMeta = m
            }
        case .data(let data):
            if let img = UIImage(data: data) {
                image = img
                if let m = pendingMeta {
                    meta = m
                    pendingMeta = nil
                }
                state = .online
            }
        @unknown default:
            break
        }
    }

    private func handleSocketFailure(_ error: Error) {
        receiveLoopRunning = false
        webSocket = nil
        guard !intentionalClose else { return }
        let msg = (error as NSError).localizedDescription
        state = .offline(shortError(msg))
        lastError = msg
        let url = (transport == .usb) ? USBTunnel.proxyURL : savedServerURL
        scheduleReconnect(to: url)
    }

    private func failAndRetry(_ reason: String) {
        state = .offline(reason)
        lastError = reason
        let url = (transport == .usb) ? USBTunnel.proxyURL : savedServerURL
        scheduleReconnect(to: url)
    }

    private func scheduleReconnect(to raw: String) {
        reconnectTask?.cancel()
        reconnectAttempt += 1
        let delay = min(8.0, pow(1.6, Double(min(reconnectAttempt, 6))))
        let t = transport
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled, !self.intentionalClose else { return }
            if t == .usb {
                USBTunnel.shared.start()
            }
            self.connect(to: raw, transport: t)
        }
    }

    private func shortError(_ s: String) -> String {
        if s.count <= 40 { return s }
        return String(s.prefix(37)) + "…"
    }
}
