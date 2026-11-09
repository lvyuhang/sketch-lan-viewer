import Foundation

struct FrameMeta: Equatable {
    var id: String?
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
        func intVal(_ key: String) -> Int? {
            if let i = obj[key] as? Int { return i }
            if let n = obj[key] as? NSNumber { return n.intValue }
            return nil
        }
        return FrameMeta(
            id: obj["id"] as? String,
            name: (obj["name"] as? String) ?? "Untitled",
            width: intVal("width"),
            height: intVal("height"),
            ts: (obj["ts"] as? NSNumber)?.doubleValue,
            bytes: intVal("bytes")
        )
    }
}

struct CatalogArtboard: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let x: Int
    let y: Int
}

struct CatalogPage: Identifiable, Equatable {
    let id: String
    let name: String
    let artboards: [CatalogArtboard]
}

struct ArtboardCatalog: Equatable {
    let pages: [CatalogPage]
    let ts: TimeInterval?

    static func parse(from data: Data) -> ArtboardCatalog? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (obj["ok"] as? Bool) != false,
              let pagesRaw = obj["pages"] as? [[String: Any]]
        else { return nil }
        func intVal(_ dict: [String: Any], _ key: String) -> Int {
            if let i = dict[key] as? Int { return i }
            if let n = dict[key] as? NSNumber { return n.intValue }
            return 0
        }
        var pages: [CatalogPage] = []
        for p in pagesRaw {
            guard let pid = p["id"] as? String else { continue }
            let pname = (p["name"] as? String) ?? "Page"
            var abs: [CatalogArtboard] = []
            for a in (p["artboards"] as? [[String: Any]]) ?? [] {
                guard let aid = a["id"] as? String else { continue }
                abs.append(CatalogArtboard(
                    id: aid,
                    name: (a["name"] as? String) ?? "Untitled",
                    width: intVal(a, "width"),
                    height: intVal(a, "height"),
                    x: intVal(a, "x"),
                    y: intVal(a, "y")
                ))
            }
            pages.append(CatalogPage(id: pid, name: pname, artboards: abs))
        }
        return ArtboardCatalog(pages: pages, ts: (obj["ts"] as? NSNumber)?.doubleValue)
    }

    func page(containingArtboardId id: String?) -> CatalogPage? {
        guard let id else { return nil }
        return pages.first { page in page.artboards.contains { $0.id == id } }
    }

    func siblings(around id: String?) -> (items: [CatalogArtboard], index: Int)? {
        guard let id, let page = page(containingArtboardId: id) else { return nil }
        guard let idx = page.artboards.firstIndex(where: { $0.id == id }) else { return nil }
        return (page.artboards, idx)
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
