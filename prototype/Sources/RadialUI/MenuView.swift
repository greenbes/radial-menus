import SwiftUI
import RadialCore

/// This view consumes values and sends events. It owns no application state.
@MainActor public struct MenuView: View {
    private let model: RenderModel
    private let reduceMotion: Bool
    private let send: (Event) -> Void
    @FocusState private var keyboardFocus: Bool
    @AccessibilityFocusState private var accessibleItem: String?

    public init(model: RenderModel, reduceMotion: Bool, send: @escaping (Event) -> Void) {
        self.model = model
        self.reduceMotion = reduceMotion
        self.send = send
    }

    public var body: some View {
        if let layout = model.layout { menu(layout).id(model.scope) }
    }

    private func menu(_ layout: MenuLayout) -> some View {
        controls(layout)
        .frame(width: layout.size.width, height: layout.size.height)
        .background {
            if let ring = layout.iconRing {
                MenuIconRing(ring: ring, items: model.items, diameter: layout.diameter,
                             fontSize: layout.fontSize, selectedID: model.selectedID)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
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
        .onKeyPress(keys: [.delete, KeyEquivalent("\u{7F}")]) { _ in back(); return .handled }
        .modifier(MenuEntrance(enabled: layout.style == .recenteredFloatingLabels, reduceMotion: reduceMotion, ready: contentChanged))
        .onChange(of: model.acceptsInput) { _, active in if active { keyboardFocus = true } }
        .onChange(of: accessibleItem) { _, item in
            if let item { emit { .select($0, item, .accessibility) } }
        }
        // Explicit children keep decoration out of single-item button bounds.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.title)
        .accessibilityChildren {
            controls(layout).frame(width: layout.size.width, height: layout.size.height)
        }
    }

    private func controls(_ layout: MenuLayout) -> some View {
        ZStack {
            ForEach(layout.contextArcs, id: \.distance) { arc in
                ForEach(arc.labels, id: \.target) { label in
                    if let entry = model.context.first(where: { $0.target == label.target }) {
                        contextLabel(entry, label: label, layout: layout)
                    }
                }
            }
            if let guide = layout.directionGuide {
                MenuDirectionGuide(guide: guide, diameter: layout.diameter, selectedID: model.selectedID)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            if layout.style == .selectedMessage {
                Circle().stroke(Color(nsColor: .windowBackgroundColor).opacity(0.8), lineWidth: 2)
                    .frame(width: layout.labelRadius * 2, height: layout.labelRadius * 2)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                let bounds = layout.labels[index].bounds
                if layout.style == .pie {
                    itemButton(item, index: index, layout: layout)
                } else {
                    itemButton(item, index: index, layout: layout)
                        .position(x: layout.size.width / 2 + bounds.x + bounds.width / 2,
                                  y: layout.size.height / 2 + bounds.y + bounds.height / 2)
                }
            }
            if layout.style == .selectedMessage {
                MenuMessageCard(message: model.message, canGoBack: model.canGoBack, fontSize: layout.fontSize,
                                height: layout.centerBounds.height, back: back)
                    .frame(width: layout.centerBounds.width, height: layout.centerBounds.height, alignment: .top)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        .allowsHitTesting(false))
            } else if !layout.style.hasEmptyCenter {
                Button(action: back) {
                    MenuCenterLabel(canGoBack: model.canGoBack, fontSize: layout.fontSize)
                    .frame(width: layout.centerRadius * 2, height: layout.centerRadius * 2)
                    .background(Color(nsColor: .windowBackgroundColor), in: Circle())
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.canGoBack ? "Back to parent menu" : "Cancel menu")
            }
        }
    }

    private func itemButton(_ item: Item, index: Int, layout: MenuLayout) -> some View {
        let selected = model.selectedID == item.id
        let isCard = layout.style == .cards
        let selectedOutline: Color = layout.style.hasEmptyCenter ? .white : .accentColor
        let outlineWidth: Double = selected ? (layout.style.hasEmptyCenter ? 3 : isCard ? 2 : 1) : 1
        let bounds = layout.labels[index].bounds
        let roundedTarget = layout.style.usesFloatingLabels || layout.style == .selectedMessage
        let cornerRadius = roundedTarget ? layout.labels[index].cornerRadius : isCard ? 17.0 : 10.0
        let labelShape = RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
        let shape = Wedge(sector: layout.sectors[index], fullCircle: model.items.count == 1,
                          outer: layout.outerRadius, inner: layout.innerRadius)
        let button = Button {
            emit { .activate($0, item.id, .pointer) }
        } label: {
            if layout.style == .pie {
                shape.fill(selected ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
                    .overlay(shape.stroke(Color.primary.opacity(0.25), lineWidth: 1))
                    .overlay {
                        MenuItemLabel(item: item, selected: selected, fontSize: layout.fontSize)
                            .foregroundStyle(selected ? .white : .primary)
                            .frame(width: layout.wrappingWidth)
                            .fixedSize(horizontal: false, vertical: true)
                            .position(x: layout.size.width / 2 + bounds.x + bounds.width / 2,
                                      y: layout.size.height / 2 + bounds.y + bounds.height / 2)
                    }
                    .contentShape(shape)
            } else {
                MenuItemLabel(item: item, selected: selected, fontSize: layout.fontSize, style: layout.style)
                    .frame(width: layout.style.usesFloatingLabels ? bounds.width : layout.wrappingWidth)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: bounds.width, height: bounds.height)
                    .foregroundStyle(selected && !isCard ? .white : .primary)
                    .background {
                        labelShape.fill(Color(nsColor: .windowBackgroundColor))
                        if selected { labelShape.fill(Color.accentColor.opacity(isCard ? 0.12 : 1)) }
                    }
                    .overlay(labelShape
                        .strokeBorder(selected ? selectedOutline : Color.primary.opacity(0.25),
                                      lineWidth: outlineWidth))
                    .contentShape(RoundedRectangle(cornerRadius: roundedTarget ? cornerRadius : 0, style: .circular))
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint([isCard ? "" : item.detail, hint(for: item)].filter { !$0.isEmpty }.joined(separator: ". "))
        .accessibilityFocused($accessibleItem, equals: item.id)
        .accessibilityAction { emit { .activate($0, item.id, .accessibility) } }
        .accessibilityAction(named: Text(model.canGoBack ? "Back to parent menu" : "Cancel menu")) { back() }
        return Group {
            if layout.style.showsFullTitles {
                // The full text is already visible. Let SwiftUI derive the
                // accessible name from that text, with decorative icons hidden.
                button
            } else {
                button.accessibilityLabel(item.title)
            }
        }
    }

    private func back() { emit { model.canGoBack ? .back($0) : .cancel($0, .user) } }

    private func contextLabel(_ entry: ContextEntry, label: ContextLabelLayout, layout: MenuLayout) -> some View {
        let shape = RoundedRectangle(cornerRadius: label.cornerRadius, style: .circular)
        return MenuContextLabel(entry: entry, fontSize: entry.fontSize(relativeTo: layout.fontSize))
        .frame(width: label.bounds.width, height: label.bounds.height)
        .foregroundStyle(Color.primary.opacity(entry.isAncestor ? 0.75 : 0.6))
        .background(shape.fill(Color(nsColor: .windowBackgroundColor).opacity(0.9)))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TitleLines.wrap(entry.title).joined(separator: "\n"))
        .accessibilityAddTraits(.isStaticText)
        .accessibilityHint("Previous menu, \(entry.distance) \(entry.distance == 1 ? "level" : "levels") back")
        .position(x: layout.size.width / 2 + label.bounds.x + label.bounds.width / 2,
                  y: layout.size.height / 2 + label.bounds.y + label.bounds.height / 2)
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
