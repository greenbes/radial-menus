import XCTest
@testable import RadialCore

/// Synthetic boundary observations; these do not stand in for native typography tests.
enum TestPresentation {
    static func measurements(_ menu: Menu) -> MenuMeasurements {
        MenuMeasurements(fontSize: 17, wrappingWidth: 96, labels: menu.items.map {
            LabelMeasurement(itemID: $0.id, normal: Size(width: 30, height: 20), selected: Size(width: 30, height: 20))
        }, center: Size(width: 36, height: 32))
    }
    static func prepared(_ model: Model) -> Event {
        guard case .preparing(let session, let operation) = model.phase else {
            preconditionFailure("Test expected menu preparation")
        }
        return .prepared(session.scope, operation, measurements(session.menu),
            ScreenContext(revision: 1, screenID: "screen",
                bounds: Rect(x: -1000, y: -500, width: 5000, height: 4000), anchor: Vector(x: 580, y: 480)))
    }
}
