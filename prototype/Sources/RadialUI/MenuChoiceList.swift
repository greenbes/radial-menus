import SwiftUI
import RadialCore

public struct MenuChoiceHeader: View {
    let title: String
    let fontSize: Double
    public init(title: String, fontSize: Double) { self.title = title; self.fontSize = fontSize }
    public var body: some View {
        Text(title).font(.system(size: fontSize * 0.85, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading).padding(fontSize * 0.8)
            .fixedSize(horizontal: false, vertical: true)
    }
}

public struct MenuChoiceRow: View {
    let choice: ListChoice
    let selected: Bool
    let fontSize: Double
    public init(choice: ListChoice, selected: Bool, fontSize: Double) {
        self.choice = choice; self.selected = selected; self.fontSize = fontSize
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.25) {
            Text(choice.title).font(.system(size: fontSize * 0.85, weight: selected ? .semibold : .regular))
            if !choice.detail.isEmpty {
                Text(choice.detail).font(.system(size: fontSize * 0.7)).opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(fontSize * 0.6)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct MenuChoiceListView: View {
    let model: RenderModel
    let layout: ChoicePanelLayout
    let fontSize: Double
    let select: (String) -> Void
    let confirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MenuChoiceHeader(title: model.choices?.title ?? "Available choices", fontSize: fontSize)
                .frame(width: layout.bounds.width, height: layout.headerHeight, alignment: .topLeading)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(model.choices?.items ?? [], id: \.id) { choice in
                            let selected = choice.id == model.selectedChoice?.id
                            Button { select(choice.id) } label: {
                                MenuChoiceRow(choice: choice, selected: selected, fontSize: fontSize)
                                    .frame(width: layout.rowWidth, height: layout.rowHeight, alignment: .leading)
                                    .foregroundStyle(selected ? .white : .primary)
                                    .background(selected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(choice.title)
                            .accessibilityValue(selected ? "Selected" : "")
                            .accessibilityIdentifier("choice-" + choice.id)
                            .id(choice.id)
                        }
                        if model.choices?.items.isEmpty ?? true {
                            Text(model.choices == nil ? "Select a menu item" : "No available choices")
                                .font(.system(size: fontSize * 0.8)).foregroundStyle(.secondary)
                                .padding(fontSize)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                }
                .scrollIndicators(.visible)
                .onChange(of: model.selectedChoice?.id, initial: true) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
            }
            // Row identifiers are unique within a category, not across categories.
            .id(model.selectedID)
            HStack {
                Text(model.browsingChoices ? "↑ ↓ Browse · Back" : "Confirm to browse")
                    .font(.system(size: fontSize * 0.7)).foregroundStyle(.secondary)
                Spacer()
                Button(model.browsingChoices ? "Choose" : "Browse", action: confirm)
                    .disabled(model.selectedChoice == nil)
            }
            .padding(.horizontal, fontSize * 0.7).frame(height: layout.footerHeight)
        }
        .frame(width: layout.bounds.width, height: layout.bounds.height)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.2)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menu-choice-list")
    }
}
