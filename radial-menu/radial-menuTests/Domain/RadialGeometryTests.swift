//
//  RadialGeometryTests.swift
//  radial-menuTests
//
//  Created by Steven Greenberg on 11/22/25.
//

import XCTest
@testable import radial_menu

final class RadialGeometryTests: XCTestCase {
    func testCalculateSlices_WithFourItems_CreatesCorrectAngles() {
        // Given
        let itemCount = 4
        let radius = 100.0
        let center = CGPoint(x: 200, y: 200)

        // When
        let slices = RadialGeometry.calculateSlices(
            itemCount: itemCount,
            radius: radius,
            centerPoint: center
        )

        // Then
        XCTAssertEqual(slices.count, 4)

        // Each slice should occupy 90 degrees (π/2 radians)
        let expectedAnglePerSlice = 2.0 * .pi / 4.0
        for (index, slice) in slices.enumerated() {
            let angleSpan = slice.endAngle - slice.startAngle
            XCTAssertEqual(angleSpan, expectedAnglePerSlice, accuracy: 0.001)
            XCTAssertEqual(slice.index, index)
        }
    }

    func testCalculateSlices_WithZeroItems_ReturnsEmptyArray() {
        // Given
        let itemCount = 0
        let radius = 100.0
        let center = CGPoint(x: 200, y: 200)

        // When
        let slices = RadialGeometry.calculateSlices(
            itemCount: itemCount,
            radius: radius,
            centerPoint: center
        )

        // Then
        XCTAssertTrue(slices.isEmpty)
    }

    func testAngleFromCenter_WithPointDirectlyRight_ReturnsZero() {
        // Given
        let center = CGPoint(x: 100, y: 100)
        let point = CGPoint(x: 200, y: 100)

        // When
        let angle = RadialGeometry.angleFromCenter(point: point, center: center)

        // Then
        XCTAssertEqual(angle, 0.0, accuracy: 0.001)
    }

    func testAngleFromCenter_WithPointDirectlyAbove_ReturnsNegativePiOverTwo() {
        // Given
        let center = CGPoint(x: 100, y: 100)
        let point = CGPoint(x: 100, y: 0)

        // When
        let angle = RadialGeometry.angleFromCenter(point: point, center: center)

        // Then
        XCTAssertEqual(angle, -.pi / 2, accuracy: 0.001)
    }

    func testDistance_BetweenTwoPoints_CalculatesCorrectly() {
        // Given
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 3, y: 4)

        // When
        let distance = RadialGeometry.distance(from: point1, to: point2)

        // Then (3-4-5 triangle)
        XCTAssertEqual(distance, 5.0, accuracy: 0.001)
    }

    func testNormalizeAngle_WithNegativeAngle_ConvertsToPositive() {
        // Given
        let angle = -.pi / 2

        // When
        let normalized = RadialGeometry.normalizeAngle(angle)

        // Then
        XCTAssertEqual(normalized, 3.0 * .pi / 2, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(normalized, 0)
        XCTAssertLessThan(normalized, 2.0 * .pi)
    }

    func testNormalizeAngle_WithAngleGreaterThanTwoPi_WrapsAround() {
        // Given
        let angle = 3.0 * .pi

        // When
        let normalized = RadialGeometry.normalizeAngle(angle)

        // Then
        XCTAssertEqual(normalized, .pi, accuracy: 0.001)
    }
}
