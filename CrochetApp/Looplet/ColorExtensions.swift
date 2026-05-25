import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// Create a Color from a CSS hex string like "#B5547D" or "B5547D".
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard h.count == 6, let rgb = UInt64(h, radix: 16) else { return nil }
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// A copy nudged toward white (`amount` > 0) — used to build vivid gradients.
    func lightened(by amount: CGFloat) -> Color { adjustingBrightness(by: amount) }
    /// A copy nudged toward black — used to build vivid gradients.
    func darkened(by amount: CGFloat) -> Color { adjustingBrightness(by: -amount) }

    private func adjustingBrightness(by delta: CGFloat) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        #elseif canImport(AppKit)
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
        return self
        #endif
        return Color(hue: Double(h), saturation: Double(s),
                     brightness: Double(min(max(b + delta, 0), 1)), opacity: Double(a))
    }

    /// Serialize the color to a CSS hex string like "#B5547D".
    /// Converts through sRGB; alpha is discarded.
    var hexString: String {
        var rC: CGFloat = 0, gC: CGFloat = 0, bC: CGFloat = 0
        #if canImport(UIKit)
        var aC: CGFloat = 0
        UIColor(self).getRed(&rC, green: &gC, blue: &bC, alpha: &aC)
        #else
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        rC = ns.redComponent; gC = ns.greenComponent; bC = ns.blueComponent
        #endif
        let r = Int((min(max(rC, 0), 1) * 255).rounded())
        let g = Int((min(max(gC, 0), 1) * 255).rounded())
        let b = Int((min(max(bC, 0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
