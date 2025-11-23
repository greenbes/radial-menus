//
//  HitDetectorTests.swift
//  radial-menuTests
//
//  Created by Steven Greenberg on 11/22/25.
//

import XCTest
@testable import radial_menu

final class HitDetectorTests: XCTestCase {
    func testHitTest_PointOutsideRadius_ReturnsOutside() {
        // Given
        let center = CGPoint(x: 100, y: 100)
        let radius = 50.0
        let centerRadius = 10.0
        let slices = createTestSlices()
        let point = CGPoint(x: 200, y: 200) // Far outside

        // When
        let result = HitDetector.hitTest(
            point: point,
            center: center,
            radius: radius,
            centerRadius: centerRadius,
            slices: slices
        )

        // Then
        XCTAssertEqual(result, .outside)
    }

    func testHitTest_PointInCenterCircle_ReturnsInCenter() {
        // Given
        let center = CGPoint(x: 100, y: 100)
        let radius = 50.0
        let centerRadius = 10.0
        let slices = createTestSlices()
        let point = CGPoint(x: 102, y: 102) // Close to center

        // When
        let result = HitDetector.hitTest(
            point: point,
            center: center,
            radius: radius,
            centerRadius: centerRadius,
            slices: slices
        )

        // Then
        XCTAssertEqual(result, .inCenter)
    }

    func testHitTest_PointInFirstSlice_ReturnsCorrectSliceIndex() {
        // Given
        let center = CGPoint(x: 100, y: 100)
        let radius = 50.0
        let centerRadius = 10.0
        let slices = createTestSlices()
        // Point in first slice (top, 12 o'clock position)
        let point = CGPoint(x: 100, y: 70)

        // When
        let result = HitDetector.hitTest(
            point: point,
            center: center,
            radius: radius,
            centerRadius: centerRadius,
            slices: slices
        )

        // Then
        if case .inSlice(let index) = result {
            XCTAssertEqual(index, 0)
        } else {
            XCTFail("Expected inSlice result, got \(result)")
        }
    }

    func testIsInsideMenu_PointAtBoundary_ReturnsTrue() {
        // Given
        let center = CGPoint(x: 100, y: 100)
        let radius = 50.0
        let point = CGPoint(x: 150, y: 100) // Exactly at radius

        // When
        let isInside = HitDetector.isInsideMenu(
            point: point,
            center: center,
            radius: radius
        )

        // Then
        XCTAssertTrue(isInside)
    }

    func testIsInsideMenu_PointJustOutside_ReturnsFalse() {
        // Given
        let center = CGPoint(x: 100, y: 100)
        let radius = 50.0
        let point = CGPoint(x: 151, y: 100) // Just beyond radius

        // When
        let isInside = HitDetector.isInsideMenu(
            point: point,
            center: center,
            radius: radius
        )

        // Then
        XCTAssertFalse(isInside)
    }

    // MARK: - Helper Methods

    private func createTestSlices() -> [RadialGeometry.Slice] {
        return RadialGeometry.calculateSlices(
            itemCount: 4,
            radius: 50.0,
            centerPoint: CGPoint(x: 100, y: 100)
        )
    }
}
