import Foundation

public struct Size: Equatable, Sendable {
    public let width: Double
    public let height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    var isValid: Bool { width.isFinite && height.isFinite && width > 0 && height > 0 }
}

public struct LabelMeasurement: Equatable, Sendable {
    public let itemID: String
    public let normal: Size
    public let selected: Size
    public init(itemID: String, normal: Size, selected: Size) {
        self.itemID = itemID; self.normal = normal; self.selected = selected
    }
}

public struct MessageMeasurement: Equatable, Sendable {
    /// nil identifies the neutral message shown before selection.
    public let itemID: String?
    public let size: Size
    public init(itemID: String?, size: Size) { self.itemID = itemID; self.size = size }
}

public struct MenuMeasurements: Equatable, Sendable {
    public enum Center: Equatable, Sendable {
        case control(Size)
        case messages(wrappingWidth: Double, states: [MessageMeasurement])
    }
    public let fontSize: Double
    public let wrappingWidth: Double
    public let labels: [LabelMeasurement]
    public let center: Center
    public let style: MenuStyle
    public init(fontSize: Double, wrappingWidth: Double, labels: [LabelMeasurement], center: Size, style: MenuStyle = .pie) {
        self.init(fontSize: fontSize, wrappingWidth: wrappingWidth, labels: labels, content: .control(center), style: style)
    }
    public init(fontSize: Double, wrappingWidth: Double, labels: [LabelMeasurement], content: Center, style: MenuStyle) {
        self.fontSize = fontSize; self.wrappingWidth = wrappingWidth
        self.labels = labels; self.center = content; self.style = style
    }

    func centerSize(for menu: Menu) throws -> Size {
        switch center {
        case .control(let size):
            guard style != .selectedMessage, size.isValid else { throw LayoutFailure.invalidMeasurements }
            return size
        case .messages(let width, let states):
            let expected = Set([nil] + menu.items.map { Optional($0.id) })
            guard style == .selectedMessage, width.isFinite, width > 0, states.count == expected.count,
                  Set(states.map(\.itemID)) == expected,
                  states.allSatisfy({ $0.size.isValid && $0.size.width <= width }) else {
                throw LayoutFailure.invalidMeasurements
            }
            return Size(width: width, height: states.map(\.size.height).max()!)
        }
    }
}

/// A copied desktop observation; it contains no native screen or window objects.
public struct ScreenContext: Equatable, Sendable {
    public let revision: UInt64
    public let screenID: String
    public let bounds: Rect
    public let anchor: Vector
    public init(revision: UInt64, screenID: String, bounds: Rect, anchor: Vector) {
        self.revision = revision; self.screenID = screenID; self.bounds = bounds; self.anchor = anchor
    }
}

public struct LayoutSettings: Equatable, Sendable {
    public let minimumInnerRadius: Double
    public let minimumOuterRadius: Double
    public let minimumLabelRadius: Double
    public let contentPadding: Double
    public let windowPadding: Double

    public init(minimumInnerRadius: Double, minimumOuterRadius: Double, minimumLabelRadius: Double,
                contentPadding: Double, windowPadding: Double) throws {
        guard [minimumInnerRadius, minimumOuterRadius, minimumLabelRadius, contentPadding, windowPadding]
            .allSatisfy({ $0.isFinite && $0 > 0 }), minimumInnerRadius > 4,
              minimumOuterRadius > minimumInnerRadius else { throw LayoutFailure.invalidSettings }
        self.minimumInnerRadius = minimumInnerRadius; self.minimumOuterRadius = minimumOuterRadius
        self.minimumLabelRadius = minimumLabelRadius; self.contentPadding = contentPadding
        self.windowPadding = windowPadding
    }

    public static let standard: Self = {
        do { return try Self(minimumInnerRadius: 46, minimumOuterRadius: 150, minimumLabelRadius: 100,
                             contentPadding: 8, windowPadding: 30) }
        catch { preconditionFailure("Invalid built-in layout settings") }
    }()
}

public enum LayoutFailure: Error, Equatable, Sendable {
    case invalidSettings, invalidMeasurements, doesNotFit
    public var message: String {
        switch self {
        case .invalidSettings: "Invalid menu layout settings"
        case .invalidMeasurements: "Missing or invalid menu measurements"
        case .doesNotFit: "The menu cannot fit on the available screen at the requested text size"
        }
    }
}

public struct LabelLayout: Equatable, Sendable {
    public let itemID: String
    /// Relative to the menu center, x right and y down.
    public let bounds: Rect
}

public struct MenuLayout: Equatable, Sendable {
    public let style: MenuStyle
    public let centerBounds: Rect
    public let fontSize: Double
    public let wrappingWidth: Double
    public let innerRadius: Double
    public let outerRadius: Double
    public let labelRadius: Double
    public let diameter: Double
    public let centerRadius: Double
    public let sectors: [Sector]
    public let labels: [LabelLayout]
    public let directionGuide: DirectionGuide?

    public static func make(menu: Menu, measurements: MenuMeasurements,
                            settings: LayoutSettings = .standard) throws -> Self {
        let measured = measurements.labels
        let centerSize = try measurements.centerSize(for: menu)
        guard measurements.fontSize.isFinite, measurements.fontSize > 0,
              measurements.wrappingWidth.isFinite, measurements.wrappingWidth > 0,
              measured.count == menu.items.count,
              Set(measured.map(\.itemID)).count == measured.count,
              Set(measured.map(\.itemID)) == Set(menu.items.map(\.id)),
              measured.allSatisfy({ $0.normal.isValid && $0.selected.isValid }) else {
            throw LayoutFailure.invalidMeasurements
        }
        let sizes = menu.items.map { item -> Size in
            let value = measured.first { $0.itemID == item.id }!
            return Size(width: max(value.normal.width, value.selected.width),
                        height: max(value.normal.height, value.selected.height))
        }
        let sectors = Geometry.sectors(count: sizes.count)
        let gap = settings.contentPadding
        let centerRadius = max(settings.minimumInnerRadius - 4,
                               hypot(centerSize.width, centerSize.height) / 2 + gap)
        let markerRadius = 5 * measurements.fontSize / 17
        let guideRadius = max(74 * measurements.fontSize / 17, centerRadius + gap + markerRadius)
        let inner: Double
        switch measurements.style {
        case .pie: inner = centerRadius + 4
        case .fullLabels, .cards: inner = guideRadius + markerRadius
        case .selectedMessage: inner = min(centerSize.width, centerSize.height) / 2
        }
        var radius = settings.minimumLabelRadius
        for (sector, size) in zip(sectors, sizes) {
            let halfWidth = size.width / 2, halfHeight = size.height / 2
            if measurements.style != .selectedMessage {
                // Wedges clear the center control; full labels clear the
                // compact ring and its direction markers.
                radius = max(radius, inner + gap + hypot(halfWidth, halfHeight))
            } else {
                // Two axis-aligned rectangles are disjoint if separated on
                // either axis. Solve each separation along this item's ray.
                let dx = abs(sin(sector.center)), dy = abs(cos(sector.center))
                let horizontal = dx > 0 ? (centerSize.width / 2 + halfWidth + gap) / dx : .infinity
                let vertical = dy > 0 ? (centerSize.height / 2 + halfHeight + gap) / dy : .infinity
                radius = max(radius, min(horizontal, vertical))
            }
            if sizes.count > 1 && measurements.style != .cards {
                // The rectangle's projection onto each sector boundary normal
                // determines how far its center must be from the menu center.
                let halfAngle = Double.pi / Double(sizes.count)
                for boundary in [sector.center - halfAngle, sector.center + halfAngle] {
                    let projection = halfWidth * abs(cos(boundary)) + halfHeight * abs(sin(boundary))
                    radius = max(radius, (projection + gap) / sin(halfAngle))
                }
            }
        }
        if measurements.style == .cards {
            radius = max(radius, CardSpacing.minimumRadius(sizes: sizes, sectors: sectors, gap: gap))
        }
        var outer = max(settings.minimumOuterRadius, centerRadius + 4)
        let labels = zip(menu.items.indices, sizes).map { index, size -> LabelLayout in
            let center = Vector(x: sin(sectors[index].center) * radius, y: -cos(sectors[index].center) * radius)
            let rect = Rect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                            width: size.width, height: size.height)
            for x in [rect.x, rect.x + rect.width] {
                for y in [rect.y, rect.y + rect.height] { outer = max(outer, hypot(x, y) + gap) }
            }
            return LabelLayout(itemID: menu.items[index].id, bounds: rect)
        }
        outer = ceil(outer)
        // A pie's visible arc needs the full circular extent. Separate buttons
        // need only their axis-aligned bounds and the decorative guide circle.
        let extent = measurements.style == .pie ? outer : labels.reduce(max(centerSize.width, centerSize.height) / 2) {
            max($0, abs($1.bounds.x), abs($1.bounds.y),
                abs($1.bounds.x + $1.bounds.width), abs($1.bounds.y + $1.bounds.height))
        }
        let diameter = ceil(2 * (max(extent, radius) + settings.windowPadding))
        guard [radius, inner, outer, diameter].allSatisfy(\.isFinite), outer > inner else {
            throw LayoutFailure.invalidMeasurements
        }
        return Self(style: measurements.style,
                    centerBounds: Rect(x: -centerSize.width / 2, y: -centerSize.height / 2,
                                       width: centerSize.width, height: centerSize.height),
                    fontSize: measurements.fontSize, wrappingWidth: measurements.wrappingWidth,
                    innerRadius: inner, outerRadius: outer, labelRadius: radius, diameter: diameter,
                    centerRadius: centerRadius, sectors: sectors, labels: labels,
                    directionGuide: measurements.style.usesDirectionGuide
                        ? DirectionGuide.make(radius: guideRadius, markerRadius: markerRadius, sectors: sectors, labels: labels) : nil)
    }

    public func placement(in screen: ScreenContext) throws -> Placement {
        guard screen.revision > 0, !screen.screenID.isEmpty,
              let frame = Geometry.place(center: screen.anchor, diameter: diameter, in: screen.bounds),
              frame.clamped(to: screen.bounds) == frame else { throw LayoutFailure.doesNotFit }
        return Placement(layout: screen.revision, screenID: screen.screenID, bounds: screen.bounds, frame: frame)
    }

    public func hit(_ point: Vector) -> Int? {
        if style != .pie {
            guard point.isFinite else { return nil }
            return labels.firstIndex { label in
                let r = label.bounds
                return point.x >= r.x && point.x <= r.x + r.width && point.y >= r.y && point.y <= r.y + r.height
            }
        }
        return Geometry.hit(point, inner: innerRadius, outer: outerRadius, count: sectors.count)
    }
}
