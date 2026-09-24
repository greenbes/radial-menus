import Foundation

public struct ChoiceSectionMeasurement: Equatable, Sendable {
    public let itemID: String
    public let header: Size
    public let rows: [LabelMeasurement]
    public init(itemID: String, header: Size, rows: [LabelMeasurement]) {
        self.itemID = itemID; self.header = header; self.rows = rows
    }
}

public struct ChoiceListMeasurements: Equatable, Sendable {
    public let width: Double
    public let rowWidth: Double
    public let placeholder: Size
    public let sections: [ChoiceSectionMeasurement]
    public init(width: Double, rowWidth: Double, placeholder: Size, sections: [ChoiceSectionMeasurement]) {
        self.width = width; self.rowWidth = rowWidth; self.placeholder = placeholder; self.sections = sections
    }

    func layout(for menu: Menu, fontSize: Double) throws -> ChoicePanelLayout {
        let items = menu.items.filter { $0.choices != nil }
        guard width.isFinite, rowWidth.isFinite, rowWidth > 0, width > rowWidth,
              placeholder.isValid, placeholder.width <= width,
              sections.count == items.count, Set(sections.map(\.itemID)) == Set(items.map(\.id)) else {
            throw LayoutFailure.invalidMeasurements
        }
        for item in items {
            guard let section = sections.first(where: { $0.itemID == item.id }),
                  section.header.isValid, section.header.width <= width,
                  section.rows.count == item.choices!.items.count,
                  Set(section.rows.map(\.itemID)) == Set(item.choices!.items.map(\.id)),
                  section.rows.allSatisfy({ $0.normal.isValid && $0.selected.isValid &&
                      $0.normal.width <= rowWidth && $0.selected.width <= rowWidth }) else {
                throw LayoutFailure.invalidMeasurements
            }
        }
        let header = max(placeholder.height, sections.map(\.header.height).max() ?? 0)
        let row = max(44 * fontSize / 17, sections.flatMap(\.rows).map { max($0.normal.height, $0.selected.height) }.max() ?? 0)
        let footer = 38 * fontSize / 17
        return ChoicePanelLayout(bounds: Rect(x: 0, y: 0, width: width, height: header + row * 4.5 + footer),
                                 headerHeight: header, rowHeight: row, rowWidth: rowWidth, footerHeight: footer)
    }
}

public struct ChoicePanelLayout: Equatable, Sendable {
    public let bounds: Rect
    public let headerHeight: Double
    public let rowHeight: Double
    public let rowWidth: Double
    public let footerHeight: Double
}

extension MenuLayout {
    /// Attach a list without changing the relative geometry of the radial menu.
    /// All hit targets remain relative to the window center; ringCenter records
    /// the translated radial origin for decoration and pie hit testing.
    func addingList(_ measured: ChoiceListMeasurements?, menu: Menu, settings: LayoutSettings) throws -> Self {
        guard let measured else {
            guard !menu.items.contains(where: { $0.choices != nil }), style != .iconLabelsCards else {
                throw LayoutFailure.invalidMeasurements
            }
            return self
        }
        let panel = try measured.layout(for: menu, fontSize: fontSize)
        let gap = fontSize * 1.3
        let right = size.width / 2 - settings.windowPadding
        let bounds = Rect(x: right + gap, y: ringCenter.y - panel.bounds.height / 2, width: panel.bounds.width, height: panel.bounds.height)
        let leftEdge = -size.width / 2
        let rightEdge = bounds.x + bounds.width + settings.windowPadding
        let topEdge = min(-size.height / 2, bounds.y - settings.windowPadding)
        let bottomEdge = max(size.height / 2, bounds.y + bounds.height + settings.windowPadding)
        let dx = -(leftEdge + rightEdge) / 2, dy = -(topEdge + bottomEdge) / 2
        func shift(_ r: Rect) -> Rect { Rect(x: r.x + dx, y: r.y + dy, width: r.width, height: r.height) }
        let expanded = Size(width: ceil(rightEdge - leftEdge), height: ceil(bottomEdge - topEdge))
        return Self(style: style, centerBounds: shift(centerBounds), messageBackBounds: messageBackBounds.map(shift),
            fontSize: fontSize, wrappingWidth: wrappingWidth, innerRadius: innerRadius, outerRadius: outerRadius,
            labelRadius: labelRadius, diameter: max(expanded.width, expanded.height), size: expanded,
            centerRadius: centerRadius, sectors: sectors,
            labels: labels.map { LabelLayout(itemID: $0.itemID, bounds: shift($0.bounds), cornerRadius: $0.cornerRadius) },
            directionGuide: directionGuide, iconRing: iconRing,
            contextArcs: contextArcs.map { arc in ContextArcLayout(distance: arc.distance, radius: arc.radius,
                startAngle: arc.startAngle, endAngle: arc.endAngle, labels: arc.labels.map {
                    ContextLabelLayout(target: $0.target, bounds: shift($0.bounds), cornerRadius: $0.cornerRadius)
                }) }, ringCenter: Vector(x: ringCenter.x + dx, y: ringCenter.y + dy),
            choicePanel: ChoicePanelLayout(bounds: shift(bounds), headerHeight: panel.headerHeight,
                rowHeight: panel.rowHeight, rowWidth: panel.rowWidth, footerHeight: panel.footerHeight))
    }
}
