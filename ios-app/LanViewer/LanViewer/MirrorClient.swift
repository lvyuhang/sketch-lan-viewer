import Foundation
import UIKit
import Combine

enum MirrorTransport: String {
    case wifi
    case usb
}

/// 对接 Sketch View / sketch-lan-mirror 本机中继：
/// - GET /health、/info、/current、/catalog
/// - POST /select（手机滑动切画板）
/// - WebSocket `/`：文本 JSON meta，随后二进制 PNG
///
/// Wi‑Fi：连 Mac 局域网地址。
/// USB：连本机 `http://127.0.0.1:9777`（由 USBTunnel + Mac LanUSBHelper 反向转到 Mac Sketch View）。
@MainActor
final class MirrorClient: ObservableObject {
    @Published var state: ConnectionState = .idle
    @Published var image: UIImage?
    @Published var meta: FrameMeta?
    @Published var lastError: String?
    @Published var transport: MirrorTransport = .wifi
    @Published var catalog: ArtboardCatalog?
    @Published var currentArtboardId: String?
    @Published var switchingArtboard = false

    private var session: URLSession?
    private var webSocket: URLSessionWebSocketTask?
    private var httpBase: URL?
    private var pendingMeta: FrameMeta?
    private var reconnectTask: Task<Void, Never>?
    private var receiveLoopRunning = false
    private var intentionalClose = false
    private var reconnectAttempt = 0
    private var pollTask: Task<Void, Never>?
    private var catalogTask: Task<Void, Never>?
    private var expectArtboardId: String?
    private var lastFrameTs: TimeInterval?
    /// Bumps on every phone-driven select; stale POST/fetch responses are dropped.
    private var selectEpoch: UInt64 = 0
    private var selectTask: Task<Void, Never>?
    /// USB /current 连续失败次数；达阈值视为掉线（Sketch 退出后不能继续冻在最后一帧）
    private var consecutiveCurrentFailures = 0
    private let currentFailureLimit = 3

    private let defaultsKey = "lan.mirror.serverURL"
    private let transportKey = "lan.mirror.transport"

    var savedServerURL: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? "http://192.168.1.1:9777" }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    func connect(to raw: String, transport: MirrorTransport = .wifi) {
        // Tear down previous HTTP/WS only — do NOT stop the USB tunnel here.
        // Stopping it on every connect() made USB reconnect permanently stuck
        // in "连接中" (tunnel died right before /health).
        teardownNetworking(intentional: false)
        self.transport = transport
        UserDefaults.standard.set(transport.rawValue, forKey: transportKey)

        guard let pair = MirrorURL.normalize(raw) else {
            state = .offline("地址格式不对")
            lastError = "请填类似 http://192.168.x.x:9777"
            return
        }
        if transport == .wifi {
            savedServerURL = pair.http.absoluteString
            USBTunnel.shared.stop()
        } else {
            USBTunnel.shared.start()
        }
        httpBase = pair.http
        intentionalClose = false
        reconnectAttempt = 0
        consecutiveCurrentFailures = 0
        state = .connecting
        lastError = nil
        catalog = nil
        switchingArtboard = false
        expectArtboardId = nil
        selectEpoch = 0

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        // Localhost USB proxy is not a "real" path; waiting hangs forever.
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        self.session = session

        Task { [weak self] in
            await self?.probeAndOpen(http: pair.http, ws: pair.ws, session: session)
        }
    }

    func disconnect(reconnect: Bool) {
        intentionalClose = !reconnect
        teardownNetworking(intentional: !reconnect)
        if !reconnect {
            state = .idle
            image = nil
            meta = nil
            catalog = nil
            currentArtboardId = nil
            switchingArtboard = false
            lastError = nil
            USBTunnel.shared.stop()
        }
    }

    /// Cancel sockets/session without necessarily killing the USB reverse proxy.
    private func teardownNetworking(intentional: Bool) {
        reconnectTask?.cancel()
        reconnectTask = nil
        pollTask?.cancel()
        pollTask = nil
        catalogTask?.cancel()
        catalogTask = nil
        selectTask?.cancel()
        selectTask = nil
        receiveLoopRunning = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
        _ = intentional
    }

    func reconnectIfNeeded() {
        guard !intentionalClose else { return }
        let url = (transport == .usb) ? USBTunnel.proxyURL : savedServerURL
        scheduleReconnect(to: url)
    }

    // MARK: - Feature A：同页左右滑

    func selectArtboard(id: String) {
        guard let session, let httpBase else { return }
        if id == expectArtboardId { return }
        selectEpoch &+= 1
        let epoch = selectEpoch
        expectArtboardId = id
        currentArtboardId = id
        switchingArtboard = true
        if let name = catalog?.pages.flatMap(\.artboards).first(where: { $0.id == id })?.name {
            meta = FrameMeta(id: id, name: name, width: meta?.width, height: meta?.height, ts: meta?.ts, bytes: meta?.bytes)
        }
        selectTask?.cancel()
        selectTask = Task { [weak self] in
            await self?.postSelect(id: id, epoch: epoch, using: session, base: httpBase)
        }
    }

    func selectAdjacentArtboard(delta: Int) {
        guard let siblings = catalog?.siblings(around: currentArtboardId) ?? catalog?.siblings(around: meta?.id) else { return }
        let next = siblings.index + delta
        guard next >= 0, next < siblings.items.count else { return }
        selectArtboard(id: siblings.items[next].id)
    }

    func selectNextArtboard() { selectAdjacentArtboard(delta: 1) }
    func selectPreviousArtboard() { selectAdjacentArtboard(delta: -1) }

    // MARK: - Private

    private func probeAndOpen(http: URL, ws: URL, session: URLSession) async {
        let healthURL = http.appendingPathComponent("health")
        // USB Peertalk needs a moment after mux attaches; retry instead of one-shot fail.
        let attempts = (transport == .usb) ? 8 : 2
        var lastErrorLocal: Error?
        var healthData: Data?
        for i in 0..<attempts {
            if intentionalClose { return }
            if transport == .usb {
                USBTunnel.shared.start()
            }
            do {
                let (data, response) = try await session.data(from: healthURL)
                guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                    lastErrorLocal = nil
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    continue
                }
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ok = obj["ok"] as? Bool, !ok {
                    failAndRetry("中继返回异常")
                    return
                }
                healthData = data
                break
            } catch {
                lastErrorLocal = error
                let delay: UInt64 = (transport == .usb) ? 300_000_000 : 200_000_000
                try? await Task.sleep(nanoseconds: delay)
                _ = i
            }
        }
        guard healthData != nil else {
            _ = lastErrorLocal
            failAndRetry(transport == .usb
                ? "USB 连不上：线插好了吗？Mac 助手开了吗？手机点过「信任」吗？"
                : "连不上 Mac（同 Wi-Fi？防火墙？地址对吗？）")
            return
        }

        await fetchCatalog(using: session, base: http)
        await fetchCurrent(using: session, base: http)
        startCatalogRefresh(using: session, base: http)
        // USB Peertalk 上 WebSocket 会秒断，改轮询 /current；Wi‑Fi 仍走 WS
        if transport == .usb {
            state = .online
            reconnectAttempt = 0
            startHTTPPoll(using: session, base: http)
        } else {
            openWebSocket(ws: ws, session: session)
        }
    }

    private func startHTTPPoll(using session: URLSession, base: URL) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                guard let self else { return }
                if self.intentionalClose { return }
                ticks += 1
                // 每 ~2.8s 探 /health：Sketch 退出后 publisherOnline=false 也能秒感知
                if ticks % 8 == 1 {
                    await self.probePublisherHealth(using: session, base: base)
                    if self.intentionalClose { return }
                    if case .offline = self.state { return }
                }
                await self.fetchCurrent(using: session, base: base)
                if case .offline = self.state { return }
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
    }

    private func probePublisherHealth(using session: URLSession, base: URL) async {
        let url = base.appendingPathComponent("health")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                noteCurrentFailure(reason: "health failed")
                return
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let online = obj["publisherOnline"] as? Bool, online == false {
                markPublisherOffline()
                return
            }
            consecutiveCurrentFailures = 0
        } catch {
            noteCurrentFailure(reason: (error as NSError).localizedDescription)
        }
    }

    private func startCatalogRefresh(using session: URLSession, base: URL) {
        catalogTask?.cancel()
        catalogTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.intentionalClose { return }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await self.fetchCatalog(using: session, base: base)
            }
        }
    }

    private func makeImage(from data: Data, logicalWidth: Int? = nil) -> UIImage? {
        guard let base = UIImage(data: data), let cg = base.cgImage else { return nil }
        let px = CGFloat(cg.width)
        let scale: CGFloat
        if let w = logicalWidth, w > 0 {
            scale = max(1, (px / CGFloat(w)).rounded())
        } else {
            let screen = UIScreen.main.scale
            scale = screen > 1 ? screen : 1
        }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }

    private func fetchCurrent(using session: URLSession, base: URL) async {
        let url = base.appendingPathComponent("current")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResp = response as? HTTPURLResponse else {
                noteCurrentFailure(reason: "无效响应")
                return
            }
            // Sketch 已退出：503，或 200 占位帧带 x-sketch-status: offline
            let sketchStatus = httpResp.value(forHTTPHeaderField: "x-sketch-status") ?? ""
            if httpResp.statusCode == 503 || sketchStatus == "offline" {
                consecutiveCurrentFailures = 0
                markPublisherOffline()
                return
            }
            // 尚无帧（刚连上）— 不算失败
            if httpResp.statusCode == 404 {
                consecutiveCurrentFailures = 0
                return
            }
            guard httpResp.statusCode == 200 else {
                noteCurrentFailure(reason: "HTTP \(httpResp.statusCode)")
                return
            }
            consecutiveCurrentFailures = 0
            applyFrame(data: data, response: httpResp)
        } catch {
            noteCurrentFailure(reason: (error as NSError).localizedDescription)
        }
    }

    private func noteCurrentFailure(reason: String) {
        consecutiveCurrentFailures += 1
        if consecutiveCurrentFailures < currentFailureLimit { return }
        consecutiveCurrentFailures = 0
        let msg = transport == .usb
            ? "已断开（Sketch 是否退出了？）"
            : "连接中断"
        lastError = reason
        failAndRetry(msg)
    }

    private func markPublisherOffline() {
        pollTask?.cancel()
        pollTask = nil
        catalogTask?.cancel()
        catalogTask = nil
        receiveLoopRunning = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        image = nil
        meta = nil
        catalog = nil
        currentArtboardId = nil
        switchingArtboard = false
        state = .offline("Sketch 已退出")
        lastError = "sketch-offline"
        // 仍自动重连：用户再开 Sketch 后应能回到预览
        let url = (transport == .usb) ? USBTunnel.proxyURL : savedServerURL
        scheduleReconnect(to: url)
    }

    private func fetchCatalog(using session: URLSession, base: URL) async {
        let url = base.appendingPathComponent("catalog")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else { return }
            if let cat = ArtboardCatalog.parse(from: data) {
                self.catalog = cat
            }
        } catch {
            // 目录还没推上来时 404，忽略
        }
    }

    private func postSelect(id: String, epoch: UInt64, using session: URLSession, base: URL) async {
        let url = base.appendingPathComponent("select")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 4
        let body: [String: Any] = ["artboardId": id]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await session.data(for: req)
            guard !Task.isCancelled, epoch == selectEpoch else { return }
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                if epoch == selectEpoch {
                    switchingArtboard = false
                    expectArtboardId = nil
                }
                return
            }
            // USB：加快等新帧；Wi‑Fi 靠 WS / 补拉。过期 epoch 直接丢弃，不排队。
            await fetchCurrent(using: session, base: base)
            guard !Task.isCancelled, epoch == selectEpoch else { return }
            if transport != .usb {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled, epoch == selectEpoch else { return }
                await fetchCurrent(using: session, base: base)
            }
        } catch {
            if Task.isCancelled || epoch != selectEpoch { return }
            switchingArtboard = false
            expectArtboardId = nil
        }
    }

    private func applyFrame(data: Data, response: HTTPURLResponse) {
        let headerId = response.value(forHTTPHeaderField: "x-artboard-id")
        let headerNameRaw = response.value(forHTTPHeaderField: "x-artboard-name")
        let headerName = headerNameRaw.flatMap { $0.removingPercentEncoding } ?? headerNameRaw
        let width = Int(response.value(forHTTPHeaderField: "x-width") ?? "")
        let height = Int(response.value(forHTTPHeaderField: "x-height") ?? "")
        let ts = TimeInterval(response.value(forHTTPHeaderField: "x-ts") ?? "")

        // Fast-swipe: while waiting for the latest target, drop frames for other ids
        // so intermediate responses never flash / queue on screen.
        if let expect = expectArtboardId, let headerId, headerId != expect {
            return
        }

        let logicalW = width ?? meta?.width
        guard let img = makeImage(from: data, logicalWidth: logicalW) else { return }

        let name = headerName ?? meta?.name ?? "Untitled"
        let newMeta = FrameMeta(
            id: headerId ?? meta?.id,
            name: name,
            width: width ?? meta?.width,
            height: height ?? meta?.height,
            ts: ts ?? Date().timeIntervalSince1970 * 1000,
            bytes: data.count
        )

        // 同帧去重：ts 不变且 id 不变就别闪
        if let ts, let lastFrameTs, abs(ts - lastFrameTs) < 0.5,
           headerId == currentArtboardId,
           !switchingArtboard {
            // still refresh image in case content changed with same ts rare
        }
        lastFrameTs = ts ?? lastFrameTs

        image = img
        meta = newMeta
        if let headerId {
            currentArtboardId = headerId
            if expectArtboardId == nil || expectArtboardId == headerId {
                switchingArtboard = false
                expectArtboardId = nil
            }
        } else if let expectArtboardId, newMeta.name == meta?.name {
            // 旧 server 无 id 头时，靠名字粗判
            _ = expectArtboardId
        }
        if state != .online { state = .online }
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
            if let expect = expectArtboardId, let pendingId = pendingMeta?.id, pendingId != expect {
                pendingMeta = nil
                return
            }
            let logicalW = pendingMeta?.width ?? meta?.width
            if let img = makeImage(from: data, logicalWidth: logicalW) {
                image = img
                if let m = pendingMeta {
                    meta = m
                    if let id = m.id {
                        currentArtboardId = id
                        if expectArtboardId == nil || expectArtboardId == id {
                            switchingArtboard = false
                            expectArtboardId = nil
                        }
                    }
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
        if transport == .usb {
            // WS 不稳时保持在线，靠 HTTP 轮询
            if let session, let httpBase {
                state = .online
                startHTTPPoll(using: session, base: httpBase)
                startCatalogRefresh(using: session, base: httpBase)
            }
            return
        }
        let msg = (error as NSError).localizedDescription
        state = .offline(shortError(msg))
        lastError = msg
        scheduleReconnect(to: savedServerURL)
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
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            self.connect(to: raw, transport: t)
        }
    }

    private func shortError(_ s: String) -> String {
        if s.count <= 40 { return s }
        return String(s.prefix(37)) + "…"
    }
}
