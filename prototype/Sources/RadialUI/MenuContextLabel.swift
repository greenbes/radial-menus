import SwiftUI
import RadialCore

/// Native measurement and display use the same complete label.
public struct MenuContextLabel: View {
    public let entry: ContextEntry
    public let fontSize: Double

    public init(entry: ContextEntry, fontSize: Double) { self.entry = entry; self.fontSize = fontSize }

    public var body: some View {
        HStack(spacing: fontSize * 0.5) {
            MenuIconGlyph(icon: entry.icon, selected: false, fontSize: fontSize).accessibilityHidden(true)
            Text(TitleLines.wrap(entry.title).joined(separator: "\n"))
                .multilineTextAlignment(.leading).fixedSize()
        }
        .font(.system(size: fontSize, weight: entry.isAncestor ? .semibold : .medium))
        .padding(.horizontal, fontSize * 0.8).padding(.vertical, fontSize * 0.6)
        .frame(minHeight: 40 * fontSize / 17).fixedSize()
    }
}

/// Animation progress belongs to the rendering boundary. The application remains
/// in its presenting phase until the animation completes, including reduced motion.
struct MenuEntrance: ViewModifier {
    let enabled: Bool
    let reduceMotion: Bool
    let ready: () -> Void
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(enabled && !reduceMotion && !revealed ? 0.82 : 1)
            .opacity(enabled && !reduceMotion && !revealed ? 0 : 1)
            .onAppear {
                if enabled && !reduceMotion {
                    withAnimation(.easeInOut(duration: 0.3), completionCriteria: .removed) {
                        revealed = true
                    } completion: { ready() }
                } else {
                    revealed = true
                    ready()
                }
            }
    }
}
