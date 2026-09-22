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
        ZStack {
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                let sector = model.sectors[index]
                let selected = model.selectedID == item.id
                let shape = Wedge(sector: sector, fullCircle: model.items.count == 1)
                Button {
                    emit { .activate($0, item.id, .pointer) }
                } label: {
                    shape.fill(selected ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
                        .overlay(shape.stroke(Color.primary.opacity(0.25), lineWidth: 1))
                        .overlay {
                            VStack(spacing: 4) {
                                Text(item.label).font(.system(size: 17, weight: selected ? .bold : .medium))
                                if case .menu = item.destination {
                                    Image(systemName: "chevron.right").font(.caption)
                                }
                            }
                            .multilineTextAlignment(.center)
                            .foregroundStyle(selected ? .white : .primary)
                            .frame(width: 96, height: 60)
                            .position(x: Geometry.diameter / 2 + sin(sector.center) * 100,
                                      y: Geometry.diameter / 2 - cos(sector.center) * 100)
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
                VStack(spacing: 5) {
                    Image(systemName: model.canGoBack ? "arrow.left" : "xmark")
                    Text(model.canGoBack ? "Back" : "Cancel").font(.caption)
                }
                .frame(width: Geometry.innerRadius * 2 - 8, height: Geometry.innerRadius * 2 - 8)
                .background(Color(nsColor: .windowBackgroundColor), in: Circle())
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.canGoBack ? "Back to parent menu" : "Cancel menu")
        }
        .frame(width: Geometry.diameter, height: Geometry.diameter)
        .disabled(!model.acceptsInput)
        .focusable()
        .focusEffectDisabled()
        .focused($keyboardFocus)
        .onKeyPress(.rightArrow) { step(1) }
        .onKeyPress(.downArrow) { step(1) }
        .onKeyPress(.leftArrow) { step(-1) }
        .onKeyPress(.upArrow) { step(-1) }
        .onKeyPress(.return) { emit { .confirm($0) }; return .handled }
        .onKeyPress(.escape) { emit { .back($0) }; return .handled }
        .onAppear { contentChanged() }
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

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = Geometry.outerRadius
        let inner = Geometry.innerRadius
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
