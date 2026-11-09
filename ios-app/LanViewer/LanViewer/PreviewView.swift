import SwiftUI

/// Preview = artboard is the product. Chrome is a quiet bottom-center chip only.
/// Critical: never remount the Image on every auto-refresh, never toggle color
/// scheme / status bar with chrome, never cover the frame with ProgressView.
/// Artboard switches get a short crossfade; same-board refresh snaps in place.
struct PreviewView: View {
    @ObservedObject var client: MirrorClient
    var onDisconnect: () -> Void

    @State private var showChrome = true
    @State private var hideChromeTask: Task<Void, Never>?

    /// Stable base frame — kept visible during switch so we never flash black/empty.
    @State private var baseImage: UIImage?
    /// Incoming frame for artboard-change crossfade only.
    @State private var incomingImage: UIImage?
    @State private var incomingOpacity: Double = 0
    @State private var displayedArtboardId: String?
    @State private var transitioningToId: String?
    @State private var transitionToken: UInt = 0

    private let switchFade: Animation = .easeInOut(duration: 0.15)

    var body: some View {
        ZStack {
            SV.bg.ignoresSafeArea()

            // Stable canvas layer — identity never depends on chrome / switching.
            // Gestures live HERE so chrome cannot swallow swipes.
            canvas
                .contentShape(Rectangle())
                .onTapGesture { toggleChrome() }
                .gesture(swipeGesture)

            // Bottom-center chip only — never a full-width gradient / material bar.
            VStack(spacing: 0) {
                if case .offline = client.state {
                    HStack {
                        Spacer(minLength: 0)
                        disconnectChip
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)
                }
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                titleChip
                    .opacity(showChrome ? 1 : 0)
                    .allowsHitTesting(showChrome)
                    .animation(SV.fade, value: showChrome)
                    .padding(.bottom, 18)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            showChrome = true
            scheduleHideChrome()
            syncCanvas(allowCrossfade: false)
        }
        .onChange(of: client.state) { _ in
            if case .offline = client.state {
                showChrome = true
                hideChromeTask?.cancel()
            }
            if case .idle = client.state {
                clearCanvas()
            }
        }
        .onChange(of: client.currentArtboardId) { _ in
            showChromeBriefly()
        }
        .onChange(of: client.image) { _ in
            syncCanvas(allowCrossfade: true)
        }
    }

    // MARK: - Canvas (stable)

    @ViewBuilder
    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                if let baseImage {
                    frameImage(baseImage, in: geo.size)
                }
                if let incomingImage {
                    frameImage(incomingImage, in: geo.size)
                        .opacity(incomingOpacity)
                }
                if baseImage == nil && incomingImage == nil {
                    emptyState
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    private func frameImage(_ image: UIImage, in size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(emptyTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SV.text1)
            Text(placeholderText)
                .font(.system(size: 13))
                .foregroundStyle(SV.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Chrome (light white rounded label, bottom-center)

    private var titleChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusDot)
                .frame(width: 5, height: 5)
            Text(client.meta?.name ?? "等待画板")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.88))
                .lineLimit(1)
            if let pos = positionLabel {
                Text(pos)
                    .font(.system(size: 10, weight: .regular).monospacedDigit())
                    .foregroundStyle(Color.black.opacity(0.45))
            }
            if client.switchingArtboard {
                Text("切换中")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel(client.meta?.name ?? "画板标题")
    }

    private var disconnectChip: some View {
        Button(action: onDisconnect) {
            Text("断开")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.88))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("断开连接")
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 48)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy), abs(dx) > 56 else { return }
                if dx < 0 {
                    client.selectNextArtboard()
                } else {
                    client.selectPreviousArtboard()
                }
                // Soft reveal of title chip only — no haptic, no rubber-band.
                showChromeBriefly()
            }
    }

    // MARK: - Canvas sync

    private func clearCanvas() {
        transitionToken &+= 1
        baseImage = nil
        incomingImage = nil
        incomingOpacity = 0
        displayedArtboardId = nil
        transitioningToId = nil
    }

    private func syncCanvas(allowCrossfade: Bool) {
        guard let img = client.image else {
            // Keep last frame while switching / reconnecting — avoid black flash.
            if !client.switchingArtboard, case .online = client.state {
                // Still online but no image yet (waiting first frame): leave empty state.
                if baseImage == nil { return }
            }
            if case .offline = client.state { clearCanvas() }
            if case .idle = client.state { clearCanvas() }
            return
        }

        let newId = client.currentArtboardId ?? client.meta?.id

        // Mid-fade: newer bytes for the same target replace the incoming layer only.
        if let to = transitioningToId, to == newId, incomingImage != nil {
            incomingImage = img
            return
        }

        let artboardChanged = displayedArtboardId != nil
            && newId != nil
            && displayedArtboardId != newId

        if allowCrossfade, artboardChanged, baseImage != nil {
            transitionToken &+= 1
            let token = transitionToken
            transitioningToId = newId
            incomingImage = img
            incomingOpacity = 0
            withAnimation(switchFade) {
                incomingOpacity = 1
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 160_000_000)
                guard token == transitionToken else { return }
                baseImage = img
                incomingImage = nil
                incomingOpacity = 0
                displayedArtboardId = newId
                transitioningToId = nil
            }
            return
        }

        // Same artboard auto-refresh, first frame, or no prior image: snap (no fade queue).
        transitionToken &+= 1
        transitioningToId = nil
        baseImage = img
        incomingImage = nil
        incomingOpacity = 0
        displayedArtboardId = newId
    }

    // MARK: - Copy

    private var emptyTitle: String {
        switch client.state {
        case .connecting: return "正在连接"
        case .online: return "等待第一帧"
        case .offline: return "已断开"
        case .idle: return "未连接"
        }
    }

    private var placeholderText: String {
        switch client.state {
        case .connecting: return "正在连 Mac…"
        case .online: return "在 Sketch 选中画板，或左右滑切换。"
        case .offline(let reason): return reason ?? "连接已断开。"
        case .idle: return "还没有连上 Mac。"
        }
    }

    private var positionLabel: String? {
        guard let siblings = client.catalog?.siblings(around: client.currentArtboardId)
                ?? client.catalog?.siblings(around: client.meta?.id) else { return nil }
        return "\(siblings.index + 1)/\(siblings.items.count)"
    }

    private var statusDot: Color {
        switch client.state {
        case .online: return SV.ok
        case .connecting: return SV.warn
        case .offline: return SV.bad
        case .idle: return SV.text3
        }
    }

    private func toggleChrome() {
        withAnimation(SV.fade) {
            showChrome.toggle()
        }
        if showChrome { scheduleHideChrome() }
        else { hideChromeTask?.cancel() }
    }

    private func showChromeBriefly() {
        withAnimation(SV.fade) { showChrome = true }
        scheduleHideChrome()
    }

    private func scheduleHideChrome() {
        hideChromeTask?.cancel()
        hideChromeTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            if case .online = client.state {
                withAnimation(SV.fade) { showChrome = false }
            }
        }
    }
}
