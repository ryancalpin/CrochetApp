import SwiftUI

enum Typo {
    /// Large counter numerals — rounded, monospaced digits, scales with Dynamic Type.
    static func counter(_ size: AppSettings.CounterSize) -> Font {
        let base: Font.TextStyle
        switch size {
        case .compact: base = .title3
        case .normal:  base = .title
        case .large:   base = .largeTitle
        }
        return .system(base, design: .rounded).weight(.bold)
    }

    static let pillLabel  = Font.caption2.weight(.semibold)
    static let sectionTitle = Font.headline
    static let bodyText   = Font.callout
    static let metadata   = Font.caption

    /// Emphasized body — primary row titles in lists.
    static let rowTitle   = Font.system(.body, weight: .medium)
    /// Small uppercase section labels in sidebars / overlays.
    static let sectionLabel = Font.caption.weight(.semibold)
    /// Card / panel sub-headers.
    static let cardTitle  = Font.system(.subheadline, weight: .semibold)
    /// Tiny pill / chip text (tags, count chips).
    static let chip       = Font.caption2.weight(.semibold)
    /// Monospaced timer / numeric readout.
    static let monoReadout = Font.system(.callout, design: .monospaced).weight(.medium)
}
