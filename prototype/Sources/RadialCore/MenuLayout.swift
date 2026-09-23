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

public struct MenuMeasurements: Equatable, Sendable {
    public let fontSize: Double
    public let wrappingWidth: Double
    public let labels: [LabelMeasurement]
    public let center: Size
    public init(fontSize: Double, wrappingWidth: Double, labels: [LabelMeasurement], center: Size) {
        self.fontSize = fontSize; self.wrappingWidth = wrappingWidth
        self.labels = labels; self.center = center
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
    public let fontSize: Double
    public let wrappingWidth: Double
    public let innerRadius: Double
    public let outerRadius: Double
    public let labelRadius: Double
    public let diameter: Double
    public let centerRadius: Double
    public let sectors: [Sector]
    public let labels: [LabelLayout]

    public static func make(menu: Menu, measurements: MenuMeasurements,
                            settings: LayoutSettings = .standard) throws -> Self {
        let measured = measurements.labels
        guard measurements.fontSize.isFinite, measurements.fontSize > 0,
              measurements.wrappingWidth.isFinite, measurements.wrappingWidth > 0,
              measurements.center.isValid, measured.count == menu.items.count,
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
                               hypot(measurements.center.width, measurements.center.height) / 2 + gap)
        let inner = centerRadius + 4
        var radius = settings.minimumLabelRadius
        for (sector, size) in zip(sectors, sizes) {
            let halfWidth = size.width / 2, halfHeight = size.height / 2
            // The bounding circle of the rectangle stays outside the center.
            radius = max(radius, inner + gap + hypot(halfWidth, halfHeight))
            if sizes.count > 1 {
                // The rectangle's projection onto each sector boundary normal
                // determines how far its center must be from the menu center.
                let halfAngle = Double.pi / Double(sizes.count)
                for boundary in [sector.center - halfAngle, sector.center + halfAngle] {
                    let projection = halfWidth * abs(cos(boundary)) + halfHeight * abs(sin(boundary))
                    radius = max(radius, (projection + gap) / sin(halfAngle))
                }
            }
        }
        var outer = settings.minimumOuterRadius
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
        let diameter = ceil(2 * (outer + settings.windowPadding))
        guard [radius, inner, outer, diameter].allSatisfy(\.isFinite), outer > inner else {
            throw LayoutFailure.invalidMeasurements
        }
        return Self(fontSize: measurements.fontSize, wrappingWidth: measurements.wrappingWidth,
                    innerRadius: inner, outerRadius: outer, labelRadius: radius, diameter: diameter,
                    centerRadius: centerRadius, sectors: sectors, labels: labels)
    }

    public func placement(in screen: ScreenContext) throws -> Placement {
        guard screen.revision > 0, !screen.screenID.isEmpty,
              let frame = Geometry.place(center: screen.anchor, diameter: diameter, in: screen.bounds),
              frame.clamped(to: screen.bounds) == frame else { throw LayoutFailure.doesNotFit }
        return Placement(layout: screen.revision, screenID: screen.screenID, bounds: screen.bounds, frame: frame)
    }

    public func hit(_ point: Vector) -> Int? {
        Geometry.hit(point, inner: innerRadius, outer: outerRadius, count: sectors.count)
    }
}
