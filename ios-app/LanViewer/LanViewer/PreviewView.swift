import SwiftUI

struct PreviewView: View {
    @ObservedObject var client: MirrorClient
    var onDisconnect: () -> Void

    @State private var showChrome = false
    @State private var hideChromeTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = client.image {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text(placeholderText)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            if showChrome {
                chromeOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleChrome() }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { flashChrome() }
        .onChange(of: client.state) { _ in
            if case .offline = client.state { showChrome = true }
        }
    }

    private var placeholderText: String {
        switch client.state {
        case .connecting: return "连接中…"
        case .online: return "已连接，等 Sketch 推第一帧\n（选中一个画板）"
        case .offline(let reason): return reason ?? "已断开"
        case .idle: return "未连接"
        }
    }

    private var chromeOverlay: some View {
        VStack {
            HStack(spacing: 10) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(client.state.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                if let name = client.meta?.name {
                    Text("·")
                        .foregroundStyle(Color(white: 0.5))
                    Text(name)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.75))
                        .lineLimit(1)
                }
                Spacer()
                Button("断开") {
                    onDisconnect()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Spacer()

            if let meta = client.meta {
                HStack(spacing: 6) {
                    if let w = meta.width, let h = meta.height {
                        Text("\(w)×\(h)")
                    }
                    if let bytes = meta.bytes {
                        Text("·")
                        Text(byteLabel(bytes))
                    }
                }
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color(white: 0.55))
                .padding(.bottom, 14)
            }
        }
    }

    private var dotColor: Color {
        switch client.state {
        case .online: return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .connecting: return Color(red: 1, green: 0.8, blue: 0)
        case .offline: return Color(red: 1, green: 0.27, blue: 0.23)
        case .idle: return Color(white: 0.4)
        }
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.15)) {
            showChrome.toggle()
        }
        if showChrome { scheduleHideChrome() }
        else { hideChromeTask?.cancel() }
    }

    private func flashChrome() {
        showChrome = true
        scheduleHideChrome()
    }

    private func scheduleHideChrome() {
        hideChromeTask?.cancel()
        hideChromeTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            if case .online = client.state {
                withAnimation { showChrome = false }
            }
        }
    }

    private func byteLabel(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1f MB", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0f KB", Double(n) / 1_000) }
        return "\(n) B"
    }
}
