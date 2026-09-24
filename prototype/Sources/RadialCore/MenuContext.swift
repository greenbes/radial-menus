import Foundation

/// Menu and item identities have separate namespaces in the validated tree.
public enum ContextID: Equatable, Hashable, Sendable {
    case menu(String), item(String)
}

public struct ContextEntry: Equatable, Sendable {
    public let target: ContextID
    public let title: String
    public let icon: ItemIcon
    public let isAncestor: Bool
    public let distance: Int

    /// Each edge away from the active menu reduces the entire label by 20%.
    /// No minimum scale: distinct ancestor levels must remain visually distinct.
    public var scale: Double { pow(0.8, Double(distance)) }

    public func fontSize(relativeTo size: Double) -> Double {
        size * scale
    }
}

/// Complete input to native measurement. Navigation history remains a core value.
public struct MenuPresentation: Equatable, Sendable {
    public let menu: Menu
    public let canGoBack: Bool
    public let style: MenuStyle
    public let context: [ContextEntry]

    public init(menu: Menu, canGoBack: Bool, style: MenuStyle, context: [ContextEntry] = []) {
        self.menu = menu; self.canGoBack = canGoBack; self.style = style; self.context = context
    }
}

extension Session {
    public var presentation: MenuPresentation {
        MenuPresentation(menu: menu, canGoBack: path.count > 1, style: style,
                         context: style == .recenteredFloatingLabels ? MenuContext.entries(path: path) : [])
    }
}

public enum MenuContext {
    /// Each previous level contains its menu title and its other choices.
    /// These are history labels, not navigation destinations.
    public static func entries(path: [Menu]) -> [ContextEntry] {
        guard path.count > 1 else { return [] }
        return (0..<(path.count - 1)).reversed().flatMap { level -> [ContextEntry] in
            let menu = path[level], distance = path.count - 1 - level
            let ancestor = ContextEntry(target: .menu(menu.id), title: menu.title, icon: .commands,
                isAncestor: true, distance: distance)
            let siblings = menu.items.compactMap { item -> ContextEntry? in
                if case .menu(let child) = item.destination, child.id == path[level + 1].id { return nil }
                return ContextEntry(target: .item(item.id), title: item.title, icon: item.icon,
                    isAncestor: false, distance: distance)
            }
            return [ancestor] + siblings
        }
    }
}
