import SwiftUI

// ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS is disabled in build
// settings so the generated Color.surface symbols don't collide with these statics.
extension Color {
    static let surface        = Color("surface")
    static let surfaceRaised  = Color("surfaceRaised")
    static let surfaceSidebar = Color("surfaceSidebar")
    static let textPrimary    = Color("textPrimary")
    static let textSecondary  = Color("textSecondary")
    static let dividerToken   = Color("divider")

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
