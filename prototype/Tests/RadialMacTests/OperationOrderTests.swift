import XCTest
import RadialCore
@testable import RadialMac

final class OperationOrderTests: XCTestCase {
    func testDelayedHideAndRepeatedShowCannotMutateCurrentWindow() {
        var order = OperationOrder()
        var mutations: [String] = []
        func apply(_ id: UInt64, _ mutation: String) {
            if order.accept(OperationID(id)) { mutations.append(mutation) }
        }
        apply(1, "show first")
        apply(2, "hide first")
        apply(3, "show second")
        apply(2, "late hide first")
        apply(3, "duplicate show second")
        apply(1, "late show first")
        XCTAssertEqual(mutations, ["show first", "hide first", "show second"])
        XCTAssertEqual(order.current, OperationID(3))
    }
}
