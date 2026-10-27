import Foundation

struct FrameMeta: Equatable {
    var name: String
    var width: Int?
    var height: Int?
    var ts: TimeInterval?
    var bytes: Int?

    static func parse(from text: String) -> FrameMeta? {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (obj["type"] as? String) == "meta" || obj["name"] != nil
        else { return nil }
        return FrameMeta(
            name: (obj["name"] as? String) ?? "Untitled",
            width: obj["width"] as? Int,
            height: obj["height"] as? Int,
            ts: (obj["ts"] as? NSNumber)?.doubleValue,
            bytes: obj["bytes"] as? Int
        )
    }
}

enum ConnectionState: Equatable {
    case idle
    case connecting
    case online
    case offline(String?)

    var label: String {
        switch self {
        case .idle: return "未连接"
        case .connecting: return "连接中…"
        case .online: return "已连接"
        case .offline(let reason):
            if let reason, !reason.isEmpty { return "已断开 · \(reason)" }
            return "已断开"
        }
    }
}

enum MirrorURL {
    /// 把用户输入规范化成 http base URL（无尾斜杠）和 ws URL。
    static func normalize(_ raw: String) -> (http: URL, ws: URL)? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if !s.contains("://") {
            s = "http://\(s)"
        }
        guard var comps = URLComponents(string: s) else { return nil }
        if comps.port == nil { comps.port = 9777 }
        if comps.host == nil || comps.host?.isEmpty == true { return nil }
        comps.path = ""
        comps.query = nil
        comps.fragment = nil
        guard let http = comps.url else { return nil }

        var wsComps = comps
        wsComps.scheme = (comps.scheme == "https") ? "wss" : "ws"
        wsComps.path = "/"
        guard let ws = wsComps.url else { return nil }
        return (http, ws)
    }

    static func displayHost(_ raw: String) -> String {
        guard let pair = normalize(raw) else { return raw }
        let host = pair.http.host ?? ""
        let port = pair.http.port ?? 9777
        return "\(host):\(port)"
    }
}
