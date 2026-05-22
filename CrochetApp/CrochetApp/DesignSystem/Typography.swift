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
}
