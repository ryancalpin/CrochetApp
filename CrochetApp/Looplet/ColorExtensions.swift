import SwiftUI
import AppKit

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

    /// Serialize the color to a CSS hex string like "#B5547D".
    /// Converts through sRGB; alpha is discarded.
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int((min(max(ns.redComponent,   0), 1) * 255).rounded())
        let g = Int((min(max(ns.greenComponent, 0), 1) * 255).rounded())
        let b = Int((min(max(ns.blueComponent,  0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
