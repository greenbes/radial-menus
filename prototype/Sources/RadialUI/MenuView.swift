import SwiftUI
import RadialCore

/// This view consumes values and sends events. It owns no application state.
@MainActor public struct MenuView: View {
    private let model: RenderModel
    private let send: (Event) -> Void
    @FocusState private var keyboardFocus: Bool
    @AccessibilityFocusState private var accessibleItem: String?

    public init(model: RenderModel, send: @escaping (Event) -> Void) {
        self.model = model
        self.send = send
    }

    public var body: some View {
        if let layout = model.layout { menu(layout) }
    }

    private func menu(_ layout: MenuLayout) -> some View {
        ZStack {
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                let sector = layout.sectors[index]
                let selected = model.selectedID == item.id
                let bounds = layout.labels[index].bounds
                let shape = Wedge(sector: sector, fullCircle: model.items.count == 1,
                                  outer: layout.outerRadius, inner: layout.innerRadius)
                Button {
                    emit { .activate($0, item.id, .pointer) }
                } label: {
                    shape.fill(selected ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
                        .overlay(shape.stroke(Color.primary.opacity(0.25), lineWidth: 1))
                        .overlay {
                            MenuItemLabel(item: item, selected: selected, fontSize: layout.fontSize)
                            .foregroundStyle(selected ? .white : .primary)
                            .frame(width: layout.wrappingWidth)
                            .fixedSize(horizontal: false, vertical: true)
                            .position(x: layout.diameter / 2 + bounds.x + bounds.width / 2,
                                      y: layout.diameter / 2 + bounds.y + bounds.height / 2)
                        }
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityValue(selected ? "Selected" : "")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityHint(hint(for: item))
                .accessibilityFocused($accessibleItem, equals: item.id)
                .accessibilityAction { emit { .activate($0, item.id, .accessibility) } }
            }
            Button {
                emit { model.canGoBack ? .back($0) : .cancel($0, .user) }
            } label: {
                MenuCenterLabel(canGoBack: model.canGoBack, fontSize: layout.fontSize)
                .frame(width: layout.centerRadius * 2, height: layout.centerRadius * 2)
                .background(Color(nsColor: .windowBackgroundColor), in: Circle())
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.canGoBack ? "Back to parent menu" : "Cancel menu")
        }
        .frame(width: layout.diameter, height: layout.diameter)
        .disabled(!model.acceptsInput)
        .focusable()
        .focusEffectDisabled()
        .focused($keyboardFocus)
        .onKeyPress(.rightArrow) { step(1) }
        .onKeyPress(.downArrow) { step(1) }
        .onKeyPress(.leftArrow) { step(-1) }
        .onKeyPress(.upArrow) { step(-1) }
        .onKeyPress(.return) { emit { .confirm($0) }; return .handled }
        .onKeyPress(.escape) { emit { .cancel($0, .user) }; return .handled }
        .onAppear { contentChanged() }
        .onChange(of: model.layout) { _, _ in contentChanged() }
        .onChange(of: model.scope) { _, _ in contentChanged() }
        .onChange(of: model.acceptsInput) { _, active in if active { keyboardFocus = true } }
        .onChange(of: accessibleItem) { _, item in
            if let item { emit { .select($0, item, .accessibility) } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.title)
    }

    private func emit(_ event: (InputScope) -> Event) {
        guard model.acceptsInput, let scope = model.scope else { return }
        send(event(scope))
    }

    private func step(_ direction: Int) -> KeyPress.Result {
        emit { .step($0, direction) }
        return .handled
    }

    private func contentChanged() {
        if let scope = model.scope { send(.contentReady(scope)) }
    }

    private func hint(for item: Item) -> String {
        if case .menu = item.destination { "Opens a submenu" } else { "Chooses this item and closes the menu" }
    }
}

private struct Wedge: Shape {
    let sector: Sector
    let fullCircle: Bool
    let outer: Double
    let inner: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // SwiftUI angles begin at the right. Domain angles begin at the top.
        let start = sector.start - .pi / 2
        let end = sector.end - .pi / 2
        var path = Path()
        if fullCircle {
            // Opposite winding leaves the center outside the button's hit area.
            path.addArc(center: center, radius: outer, startAngle: .radians(0), endAngle: .radians(2 * .pi), clockwise: false)
            path.closeSubpath()
            path.addArc(center: center, radius: inner, startAngle: .radians(0), endAngle: .radians(-2 * .pi), clockwise: true)
            path.closeSubpath()
        } else {
            path.addArc(center: center, radius: outer, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
            path.addLine(to: CGPoint(x: center.x + cos(end) * inner, y: center.y + sin(end) * inner))
            path.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
            path.closeSubpath()
        }
        return path
    }
}
