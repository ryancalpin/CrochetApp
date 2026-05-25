import SwiftUI

struct CounterPill: View {
    let label: String
    let value: Int
    let goal: Int?
    let color: Color
    let size: AppSettings.CounterSize
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    private var pillHeight: CGFloat { size.pillHeight }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus", enabled: value > 0, action: onDecrement)
                .accessibilityLabel("Decrease \(label)")
            Divider().frame(maxHeight: .infinity)
            VStack(spacing: 1) {
                HStack(spacing: 3) {
                    Text(label).font(Typo.pillLabel).foregroundColor(color)
                    if let goal { Text("/ \(goal)").font(Typo.pillLabel).foregroundColor(color.opacity(0.6)) }
                }
                Text("\(value)")
                    .font(Typo.counter(size)).monospacedDigit()
                    .foregroundColor(color)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: value)
            }
            .frame(minWidth: 48).padding(.horizontal, 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue("\(value)")
            Divider().frame(maxHeight: .infinity)
            stepButton(systemName: "plus", enabled: true, action: onIncrement)
                .accessibilityLabel("Increase \(label)")
        }
        .frame(minHeight: pillHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(color.opacity(0.18), lineWidth: 1.5))
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: pillHeight)
                .frame(maxHeight: .infinity)
                .background(color.opacity(0.10))
                .foregroundColor(enabled ? color : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
