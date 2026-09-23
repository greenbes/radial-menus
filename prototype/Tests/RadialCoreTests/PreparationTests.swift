import XCTest
@testable import RadialCore

final class PreparationTests: XCTestCase {
    func testOpeningWaitsForMeasurementsThenPresentationBeforeInput() throws {
        let opened = update(Model(menu: SampleMenu.definition), .open(nil))
        let model = opened.model, scope = try XCTUnwrap(model.phase.session?.scope)
        let operation = try XCTUnwrap(model.phase.operation)
        XCTAssertEqual(opened.effects, [.prepare(scope, model.menu, false, operation)])
        XCTAssertEqual(subscriptions(model).filter { if case .deadline = $0 { true } else { false } }, [.deadline(operation)])
        XCTAssertNil(render(model).layout)
        for event in [Event.presented(operation), .contentReady(scope), .activate(scope, "red", .pointer)] {
            XCTAssertEqual(update(model, event).model, model)
            XCTAssertTrue(update(model, event).effects.isEmpty)
        }
        let prepared = update(model, TestPresentation.prepared(model))
        guard case .present(let receivedScope, let layout, let placement, let presentation) = prepared.effects.first else {
            return XCTFail("Missing presentation with calculated layout")
        }
        XCTAssertEqual(receivedScope, scope)
        XCTAssertEqual(layout, render(prepared.model).layout)
        XCTAssertEqual(placement.frame.width, layout.diameter)
        XCTAssertGreaterThan(presentation, operation)
        XCTAssertFalse(render(prepared.model).acceptsInput)
        XCTAssertTrue(update(prepared.model, .presented(presentation)).model.phase.isActive)
        XCTAssertEqual(update(prepared.model, TestPresentation.prepared(model)).model, prepared.model)
    }

    func testLateMeasurementsCannotEscapeCancellationShutdownOrNewSession() throws {
        let opening = update(Model(menu: SampleMenu.definition), .open(nil)).model
        let scope = try XCTUnwrap(opening.phase.session?.scope), event = TestPresentation.prepared(opening)
        for interruption in [Event.cancel(scope, .user), .stop, .deadline(opening.phase.operation!)] {
            let interrupted = update(opening, interruption).model
            let late = update(interrupted, event)
            XCTAssertEqual(late.model, interrupted)
            XCTAssertTrue(late.effects.isEmpty)
            XCTAssertTrue(late.outputs.isEmpty)
        }
        let cancelled = update(opening, .cancel(scope, .user)).model
        let idle = update(cancelled, .dismissed(cancelled.phase.operation!)).model
        let reopened = update(idle, .open(nil)).model
        XCTAssertEqual(update(reopened, event).model, reopened)
        let wrongScope = InputScope(session: scope.session, revision: 999)
        guard case .prepared(_, let op, let measurements, let screen) = event else { return XCTFail() }
        XCTAssertEqual(update(opening, .prepared(wrongScope, op, measurements, screen)).model, opening)
        XCTAssertEqual(update(opening, .prepared(scope, OperationID(999), measurements, screen)).model, opening)
    }

    func testInvalidMeasurementsOrSmallScreenRequireCleanupBeforeFailure() throws {
        let opening = update(Model(menu: SampleMenu.definition), .open(nil)).model
        guard case .prepared(let scope, let operation, let measurements, let screen) = TestPresentation.prepared(opening) else {
            return XCTFail()
        }
        let invalid = MenuMeasurements(fontSize: 17, wrappingWidth: 96, labels: [], center: Size(width: 20, height: 20))
        let small = ScreenContext(revision: 1, screenID: "small", bounds: Rect(x: 0, y: 0, width: 100, height: 100), anchor: .zero)
        for event in [Event.prepared(scope, operation, invalid, screen), .prepared(scope, operation, measurements, small)] {
            let failed = update(opening, event)
            XCTAssertTrue(failed.outputs.isEmpty)
            XCTAssertEqual(failed.model.phase.name, "Dismissing")
            XCTAssertFalse(failed.effects.contains { if case .present = $0 { true } else { false } })
            let dismissed = update(failed.model, .dismissed(failed.model.phase.operation!))
            guard case .completed(scope.session, .failed(let failure)) = dismissed.outputs.first else { return XCTFail() }
            XCTAssertTrue(failure.cleanupConfirmed)
            XCTAssertNil(failure.committedChoice)
            XCTAssertEqual(dismissed.model.phase, .idle)
        }
    }

    func testPreparationDeadlineRequiresCleanupAndPreservesFailure() throws {
        let opening = update(Model(menu: SampleMenu.definition), .open(nil)).model
        let operation = try XCTUnwrap(opening.phase.operation)
        let expired = update(opening, .deadline(operation))
        XCTAssertEqual(expired.model.phase.name, "Dismissing")
        XCTAssertTrue(expired.outputs.isEmpty)
        let completion = update(expired.model, .dismissed(try XCTUnwrap(expired.model.phase.operation)))
        guard case .completed(_, .failed(let failure)) = completion.outputs.first else { return XCTFail() }
        XCTAssertEqual(failure.message, "Native operation timed out")
        XCTAssertTrue(failure.cleanupConfirmed)
        XCTAssertEqual(update(completion.model, TestPresentation.prepared(opening)).model, completion.model)
    }

    func testSubmenuRequiresFreshMeasurementsAndDiscardsParentLayout() throws {
        let opening = update(Model(menu: SampleMenu.definition), .open(nil)).model
        let prepared = update(opening, TestPresentation.prepared(opening)).model
        let active = update(prepared, .presented(prepared.phase.operation!)).model
        let parent = active.phase.session!.scope
        let child = update(active, .activate(parent, "more", .keyboard))
        let scope = try XCTUnwrap(child.model.phase.session?.scope)
        XCTAssertEqual(scope.session, parent.session)
        XCTAssertGreaterThan(scope.revision, parent.revision)
        XCTAssertNil(render(child.model).layout)
        guard case .prepare(scope, let menu, true, _) = child.effects.last else { return XCTFail() }
        XCTAssertEqual(menu.id, "colors")
        XCTAssertEqual(update(child.model, TestPresentation.prepared(opening)).model, child.model)
    }

    func testExpandedLayoutDrivesPointerAndRejectsMismatchedNativeFrame() throws {
        let menu = try Menu(id: "root", title: "Large", items: (0..<12).map { Item(id: "\($0)", label: "Wide label", value: "\($0)") })
        var model = update(Model(menu: menu), .open(nil)).model
        let scope = model.phase.session!.scope
        let size = Size(width: 96, height: 100)
        let measurements = MenuMeasurements(fontSize: 17, wrappingWidth: 96,
            labels: menu.items.map { LabelMeasurement(itemID: $0.id, normal: size, selected: size) }, center: Size(width: 36, height: 32))
        let screen = ScreenContext(revision: 1, screenID: "screen", bounds: Rect(x: 0, y: 0, width: 2000, height: 1400), anchor: Vector(x: 1000, y: 700))
        model = update(model, .prepared(scope, model.phase.operation!, measurements, screen)).model
        let layout = try XCTUnwrap(model.phase.session?.layout)
        let placement = try layout.placement(in: screen)
        model = update(model, .placementObserved(scope, placement)).model
        model = update(model, .presented(model.phase.operation!)).model
        XCTAssertGreaterThan(layout.labelRadius, 150)
        func pointer(_ sequence: UInt64, _ screenX: Double, _ local: Vector) -> PointerSample {
            PointerSample(sequence: sequence, timestamp: Double(sequence), layout: 1,
                          screenPosition: Vector(x: screenX, y: 700), menuPosition: local)
        }
        model = update(model, .pointerBaseline(scope, pointer(1, 1000, .zero))).model
        model = update(model, .pointerMoved(scope, pointer(2, 1010, Vector(x: 0, y: -layout.labelRadius)))).model
        XCTAssertEqual(render(model).selectedID, "0")
        model = update(model, .pointerMoved(scope, pointer(3, 1020, Vector(x: 0, y: -layout.outerRadius - 1)))).model
        XCTAssertNil(render(model).selectedID)
        let wrongSize = Placement(layout: 2, screenID: "screen", bounds: screen.bounds, frame: Rect(x: 0, y: 0, width: 360, height: 360))
        let failed = update(model, .placementObserved(scope, wrongSize))
        guard case .dismissing(_, _, .cancelled(.layoutUnavailable)) = failed.model.phase else { return XCTFail() }
    }
}
