import SwiftUI
import RadialCore

/// Measured and rendered as one button, including the complete description.
struct MenuItemCard: View {
    let item: Item
    let selected: Bool
    let fontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.6) {
            HStack(alignment: .top, spacing: fontSize * 0.5) {
                Text(item.title)
                    .font(.system(size: fontSize, weight: selected ? .bold : .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark" : "chevron.right")
                    .font(.system(size: fontSize * 0.8, weight: .semibold))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(width: fontSize)
                    .opacity(selected || isSubmenu ? 1 : 0)
                    .accessibilityHidden(true)
            }
            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.system(size: fontSize * 0.85))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(fontSize * 0.85)
    }

    private var isSubmenu: Bool {
        if case .menu = item.destination { true } else { false }
    }
}
