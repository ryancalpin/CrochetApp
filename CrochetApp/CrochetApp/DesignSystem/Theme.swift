import SwiftUI

// MARK: - App theme

/// A selectable, coordinated palette: one accent + matched surface/text/divider tones
/// for light and dark. Choosing a theme re-skins the whole UI cohesively, so chrome
/// no longer borrows the (independent) counter colors.
enum AppTheme: String, CaseIterable, Identifiable {
    case plum, amber, rose, slate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plum:  return "Plum"
        case .amber: return "Amber"
        case .rose:  return "Rose"
        case .slate: return "Slate"
        }
    }

    struct Palette {
        let accent: String
        let surfaceL, surfaceD: String
        let raisedL, raisedD: String
        let sidebarL, sidebarD: String
        let textL, textD: String
        let text2L, text2D: String
        let divL, divD: String
    }

    var palette: Palette {
        switch self {
        case .plum:
            return Palette(accent: "#8E72C7",
                surfaceL: "#F7F3FB", surfaceD: "#1A1622",
                raisedL: "#FFFFFF", raisedD: "#262031",
                sidebarL: "#EFE8F6", sidebarD: "#15111D",
                textL: "#2F2A3D", textD: "#E9E3F2",
                text2L: "#6C6580", text2D: "#A498B6",
                divL: "#E5DDEF", divD: "#2F2840")
        case .amber:
            return Palette(accent: "#C8893A",
                surfaceL: "#FBF6EF", surfaceD: "#1C1813",
                raisedL: "#FFFFFF", raisedD: "#29241D",
                sidebarL: "#F3E9DC", sidebarD: "#17140F",
                textL: "#3A2F26", textD: "#ECE0D2",
                text2L: "#7A6A58", text2D: "#A99E8E",
                divL: "#ECE0D0", divD: "#302A21")
        case .rose:
            return Palette(accent: "#C65C84",
                surfaceL: "#FCF1F5", surfaceD: "#1F161B",
                raisedL: "#FFFFFF", raisedD: "#2B2026",
                sidebarL: "#F6E5EC", sidebarD: "#1A1216",
                textL: "#38262F", textD: "#F1DDE5",
                text2L: "#7E6670", text2D: "#B1969F",
                divL: "#EFDAE2", divD: "#342731")
        case .slate:
            return Palette(accent: "#4F80B6",
                surfaceL: "#F1F5F9", surfaceD: "#14181D",
                raisedL: "#FFFFFF", raisedD: "#1F262D",
                sidebarL: "#E6ECF3", sidebarD: "#11151A",
                textL: "#25303B", textD: "#DCE6F1",
                text2L: "#5E6E7E", text2D: "#8E9EAF",
                divL: "#DBE3EC", divD: "#232C35")
        }
    }

    /// SwiftUI accent color for swatches/previews.
    var accentColor: Color { ThemeColor.color(palette.accent) }
}

// MARK: - Hex → color helpers

enum ThemeColor {
    static func ns(_ hex: String) -> NSColor {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
    static func color(_ hex: String) -> Color { Color(nsColor: ns(hex)) }

    /// Theme-driven surface as a dynamic NSColor (for AppKit consumers like PDFView).
    static var surfaceNS: NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let p = AppSettings.shared.appTheme.palette
            return ns(isDark ? p.surfaceD : p.surfaceL)
        }
    }
}

// MARK: - Theme-driven color tokens
//
// These resolve from the currently-selected AppTheme at draw time (and per light/dark
// appearance), so the whole UI re-skins when the theme changes. View code keeps using
// `Color.surface`, `Color.appAccent`, etc. unchanged.
extension Color {
    private static func themed(_ pick: @escaping (AppTheme.Palette, Bool) -> String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return ThemeColor.ns(pick(AppSettings.shared.appTheme.palette, isDark))
        })
    }

    static var surface: Color        { themed { p, d in d ? p.surfaceD : p.surfaceL } }
    static var surfaceRaised: Color  { themed { p, d in d ? p.raisedD  : p.raisedL  } }
    static var surfaceSidebar: Color { themed { p, d in d ? p.sidebarD : p.sidebarL } }
    static var textPrimary: Color    { themed { p, d in d ? p.textD    : p.textL    } }
    static var textSecondary: Color  { themed { p, d in d ? p.text2D   : p.text2L   } }
    static var dividerToken: Color   { themed { p, d in d ? p.divD     : p.divL     } }

    /// The single app accent for all chrome (selection, buttons, links, AI, chips).
    /// Counter pill colors are independent of this.
    static var appAccent: Color { themed { p, _ in p.accent } }

    /// Keep hue; nudge lightness/saturation so a user-picked accent stays legible on the
    /// current background. Dark mode: ensure not-too-dark. Light mode: ensure not-too-pale.
    func legible(in scheme: ColorScheme) -> Color {
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if scheme == .dark { b = max(b, 0.62); s = min(s, 0.85) }
        else { b = min(b, 0.78) }
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b))
    }
}
