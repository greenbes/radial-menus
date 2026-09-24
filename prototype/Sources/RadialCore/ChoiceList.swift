import Foundation

/// A finite snapshot of choices, independent of how a shell obtains it.
public struct ListChoice: Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let value: String
    public init(id: String, title: String, detail: String = "", value: String) {
        self.id = id; self.title = title; self.detail = detail; self.value = value
    }
}

public struct ChoiceList: Equatable, Sendable {
    public let title: String
    public let items: [ListChoice]
    public init(title: String, items: [ListChoice]) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 160,
              items.count <= 256, Set(items.map(\.id)).count == items.count,
              items.allSatisfy({ !$0.id.isEmpty && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.title.count <= 160 && $0.detail.count <= 600 }) else { throw ValidationError.invalidItem(title) }
        self.title = title; self.items = items
    }
}

extension Session {
    public var choices: ChoiceList? { menu.items.first { $0.id == selection?.itemID }?.choices }
    public var selectedChoice: ListChoice? {
        choices?.items.first { $0.id == choiceID } ?? choices?.items.first
    }
    func choosing(_ id: String?, browsing: Bool) -> Self {
        Self(scope: scope, path: path, selection: selection, owner: owner, layout: layout, style: style,
             choiceID: id, browsingChoices: browsing)
    }
}

extension Change {
    mutating func selectChoice(_ scope: InputScope, item: String, choice: String) {
        guard let session = active(scope), session.selection?.itemID == item,
              session.choices?.items.contains(where: { $0.id == choice }) == true else { return }
        phase = .active(session.choosing(choice, browsing: true))
    }

    mutating func stepChoice(_ scope: InputScope, _ direction: Int) {
        guard let session = active(scope), direction == 1 || direction == -1,
              let choices = session.choices?.items, !choices.isEmpty else { return }
        let current = choices.firstIndex { $0.id == session.selectedChoice?.id } ?? 0
        let next = min(choices.count - 1, max(0, current + direction))
        phase = .active(session.choosing(choices[next].id, browsing: true))
    }
}
