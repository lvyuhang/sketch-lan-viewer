import SwiftUI

/// Quiet tool UI tokens — Notion / Cursor / Linear adjacent.
/// Flat surfaces, typography hierarchy, one quiet accent. No materials-as-chrome.
enum SV {
    // MARK: Color
    static let bg = Color(hex: 0x0F0F10)
    static let bgElevated = Color(hex: 0x161618)
    static let surface = Color(hex: 0x1C1C1F)
    static let hairline = Color.white.opacity(0.08)

    static let text1 = Color(hex: 0xEDEDEF)
    static let text2 = Color(hex: 0x8A8F98)
    static let text3 = Color(hex: 0x5C616A)

    /// Linear-ish indigo — use sparingly (one control / status).
    static let accent = Color(hex: 0x5E6AD2)
    static let accentSoft = Color(hex: 0x5E6AD2).opacity(0.14)

    static let ok = Color(hex: 0x3D9A6A)
    static let warn = Color(hex: 0xC49A3C)
    static let bad = Color(hex: 0xC45454)

    // Light connect screen
    static let lightBg = Color(hex: 0xFAFAFA)
    static let lightSurface = Color(hex: 0xFFFFFF)
    static let lightHairline = Color(hex: 0xE6E6E6)
    static let lightText1 = Color(hex: 0x1A1A1A)
    static let lightText2 = Color(hex: 0x6B6B6B)
    static let lightText3 = Color(hex: 0x9A9A9A)

    // MARK: Motion — calm, no spring showiness
    static let fade: Animation = .easeOut(duration: 0.18)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
