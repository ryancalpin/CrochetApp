import SwiftUI

// MARK: - App theme

/// A selectable, coordinated palette: one accent + matched surface/text/divider tones
/// for light and dark. Choosing a theme re-skins the whole UI cohesively, so chrome
/// no longer borrows the (independent) counter colors.
enum AppTheme: String, CaseIterable, Identifiable {
    case plum, amber, rose, slate, forest, teal, sand, graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plum:     return "Plum"
        case .amber:    return "Amber"
        case .rose:     return "Rose"
        case .slate:    return "Slate"
        case .forest:   return "Forest"
        case .teal:     return "Teal"
        case .sand:     return "Sand"
        case .graphite: return "Graphite"
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
        // Coordinated counter-pill defaults (row / stitch / repeat). Used out of the
        // box unless the user picks custom counter colors. `.legible(in:)` adapts
        // brightness per light/dark at draw time, so these are mid-tone base hues.
        let counterRow, counterStitch, counterRepeat: String
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
                divL: "#E5DDEF", divD: "#2F2840",
                counterRow: "#B5547D", counterStitch: "#8A63C6", counterRepeat: "#2F9E8F")
        case .amber:
            return Palette(accent: "#C8893A",
                surfaceL: "#FBF6EF", surfaceD: "#1C1813",
                raisedL: "#FFFFFF", raisedD: "#29241D",
                sidebarL: "#F3E9DC", sidebarD: "#17140F",
                textL: "#3A2F26", textD: "#ECE0D2",
                text2L: "#7A6A58", text2D: "#A99E8E",
                divL: "#ECE0D0", divD: "#302A21",
                counterRow: "#C25A43", counterStitch: "#B0863A", counterRepeat: "#5E8C6A")
        case .rose:
            return Palette(accent: "#C65C84",
                surfaceL: "#FCF1F5", surfaceD: "#1F161B",
                raisedL: "#FFFFFF", raisedD: "#2B2026",
                sidebarL: "#F6E5EC", sidebarD: "#1A1216",
                textL: "#38262F", textD: "#F1DDE5",
                text2L: "#7E6670", text2D: "#B1969F",
                divL: "#EFDAE2", divD: "#342731",
                counterRow: "#C4567E", counterStitch: "#9E5BB0", counterRepeat: "#4E97A2")
        case .slate:
            return Palette(accent: "#4F80B6",
                surfaceL: "#F1F5F9", surfaceD: "#14181D",
                raisedL: "#FFFFFF", raisedD: "#1F262D",
                sidebarL: "#E6ECF3", sidebarD: "#11151A",
                textL: "#25303B", textD: "#DCE6F1",
                text2L: "#5E6E7E", text2D: "#8E9EAF",
                divL: "#DBE3EC", divD: "#232C35",
                counterRow: "#5A82B6", counterStitch: "#7E72BE", counterRepeat: "#4F9E8C")
        case .forest:
            return Palette(accent: "#4E9A6B",
                surfaceL: "#F1F7F2", surfaceD: "#141A16",
                raisedL: "#FFFFFF", raisedD: "#1F2922",
                sidebarL: "#E5F0E8", sidebarD: "#101510",
                textL: "#25332B", textD: "#DCEFE0",
                text2L: "#5E7064", text2D: "#8EAF98",
                divL: "#DBEADF", divD: "#232E26",
                counterRow: "#57A06E", counterStitch: "#C58A3E", counterRepeat: "#5189B0")
        case .teal:
            return Palette(accent: "#2FA3A8",
                surfaceL: "#EFF6F7", surfaceD: "#121A1B",
                raisedL: "#FFFFFF", raisedD: "#1D2829",
                sidebarL: "#E2EFF0", sidebarD: "#0F1516",
                textL: "#213437", textD: "#D6EEEF",
                text2L: "#5A6E70", text2D: "#8CA8AA",
                divL: "#D6E7E8", divD: "#21302F",
                counterRow: "#2FA0A5", counterStitch: "#5E83BE", counterRepeat: "#C58455")
        case .sand:
            return Palette(accent: "#B08A5A",
                surfaceL: "#F8F4ED", surfaceD: "#1A1713",
                raisedL: "#FFFFFF", raisedD: "#26221C",
                sidebarL: "#F0EAE0", sidebarD: "#15120E",
                textL: "#332E26", textD: "#EAE3D5",
                text2L: "#6E665A", text2D: "#A89E8C",
                divL: "#E7E0D2", divD: "#2D281F",
                counterRow: "#B07A4E", counterStitch: "#8C7BB0", counterRepeat: "#5E9277")
        case .graphite:
            return Palette(accent: "#828A94",
                surfaceL: "#F4F5F6", surfaceD: "#161719",
                raisedL: "#FFFFFF", raisedD: "#212327",
                sidebarL: "#E9EBED", sidebarD: "#131416",
                textL: "#2A2D30", textD: "#E4E6E9",
                text2L: "#5F6469", text2D: "#969A9F",
                divL: "#DEE0E3", divD: "#2A2C30",
                counterRow: "#8C7FA0", counterStitch: "#6E8AA0", counterRepeat: "#7FA088")
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
