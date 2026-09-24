import Foundation

/// Built-in semantic symbols. The presentation layer chooses their artwork.
public enum ItemIcon: String, CaseIterable, Equatable, Sendable {
    case item, documents, workspace, writing, history, capture, commands, color, terminal
}

public struct Item: Equatable, Sendable {
    public enum Destination: Equatable, Sendable { case value(String), menu(Menu), choices(ChoiceList) }
    public let id: String
    public let label: String
    public let title: String
    public let detail: String
    public let icon: ItemIcon
    public let destination: Destination

    public var choices: ChoiceList? {
        if case .choices(let list) = destination { return list }
        return nil
    }

    public init(id: String, label: String, title: String? = nil, detail: String = "", icon: ItemIcon = .item, choices: ChoiceList) {
        self.id = id; self.label = label; self.title = title ?? label; self.detail = detail
        self.icon = icon; self.destination = .choices(choices)
    }

    public init(id: String, label: String, title: String? = nil, detail: String = "", icon: ItemIcon = .item, value: String) {
        self.icon = icon
        self.title = title ?? label; self.detail = detail
        self.id = id; self.label = label; self.destination = .value(value)
    }

    public init(id: String, label: String, title: String? = nil, detail: String = "", icon: ItemIcon = .commands, menu: Menu) {
        self.icon = icon
        self.title = title ?? label; self.detail = detail
        self.id = id; self.label = label; self.destination = .menu(menu)
    }
}

public struct Menu: Equatable, Sendable {
    public let id: String
    public let title: String
    public let items: [Item]

    public init(id: String, title: String, items: [Item]) throws {
        self.id = id; self.title = title; self.items = items
        var menuIDs = Set<String>()
        var itemIDs = Set<String>()
        var total = 0
        try Self.validate(self, depth: 1, menus: &menuIDs, items: &itemIDs, total: &total)
    }

    private static func validate(_ menu: Menu, depth: Int, menus: inout Set<String>,
                                 items: inout Set<String>, total: inout Int) throws {
        guard depth <= 8, (1...12).contains(menu.items.count),
              !menu.id.isEmpty, !menu.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              menu.title.count <= 32, menus.insert(menu.id).inserted else {
            throw ValidationError.invalidMenu(menu.id)
        }
        for item in menu.items {
            total += 1
            guard total <= 256, !item.id.isEmpty, items.insert(item.id).inserted,
                  !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.label.count <= 24,
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.title.count <= 160, item.detail.count <= 600 else { throw ValidationError.invalidItem(item.id) }
            if case .menu(let child) = item.destination {
                try validate(child, depth: depth + 1, menus: &menus, items: &items, total: &total)
            }
        }
    }
}

public enum ValidationError: Error, Equatable { case invalidMenu(String), invalidItem(String) }

public enum SampleMenu {
    public static let definition: Menu = {
        do {
            let colors = try Menu(id: "colors", title: "More colors", items: [
                Item(id: "amber", label: "Amber", icon: .color, value: "amber"),
                Item(id: "violet", label: "Violet", icon: .color, value: "violet")
            ])
            return try Menu(id: "root", title: "Choose a color", items: [
                Item(id: "red", label: "Red", icon: .color, value: "red"),
                Item(id: "blue", label: "Blue", icon: .color, value: "blue"),
                Item(id: "green", label: "Green", icon: .color, value: "green"),
                Item(id: "more", label: "More colors", menu: colors)
            ])
        } catch { preconditionFailure("Invalid built-in fixture: \(error)") }
    }()
}
