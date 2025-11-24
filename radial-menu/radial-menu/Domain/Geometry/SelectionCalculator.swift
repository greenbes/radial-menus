//
//  SelectionCalculator.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import CoreGraphics

/// Pure functions for calculating slice selection
enum SelectionCalculator {
    /// Calculate which slice should be selected based on a point
    /// - Parameters:
    ///   - point: The point (e.g., mouse position)
    ///   - center: Center of the radial menu
    ///   - centerRadius: Inner radius (center circle)
    ///   - slices: Array of slices
    /// - Returns: Index of selected slice, or nil if none selected
    static func selectedSlice(
        fromPoint point: CGPoint,
        center: CGPoint,
        centerRadius: Double,
        outerRadius: Double,
        slices: [RadialGeometry.Slice]
    ) -> Int? {
        let distance = RadialGeometry.distance(from: center, to: point)

        // If in center circle or outside outer radius, no selection
        if distance < centerRadius || distance > outerRadius {
            // Log("📏 SelectionCalculator: Distance \(distance) out of bounds (\(centerRadius)-\(outerRadius))")
            return nil
        }

        let angle = RadialGeometry.angleFromCenter(point: point, center: center)
        let normalizedAngle = RadialGeometry.normalizeAngle(angle)
        
        // Log("📐 SelectionCalculator: Center: \(center), Point \(point) -> Dist: \(distance), Angle: \(angle) (Norm: \(normalizedAngle))")
        
        // 1. Check distance (Ring check)

        return selectedSlice(fromAngle: normalizedAngle, slices: slices)
    }

    /// Calculate which slice should be selected based on an angle
    /// - Parameters:
    ///   - angle: The angle in radians (normalized to 0...2π)
    ///   - slices: Array of slices
    /// - Returns: Index of selected slice, or nil if none
    static func selectedSlice(
        fromAngle angle: Double,
        slices: [RadialGeometry.Slice]
    ) -> Int? {
        for slice in slices {
            let normalizedStart = RadialGeometry.normalizeAngle(slice.startAngle)
            let normalizedEnd = RadialGeometry.normalizeAngle(slice.endAngle)
            
            // Log("🍰 Checking slice \(slice.index): \(normalizedStart) -> \(normalizedEnd) vs \(angle)")

            // Handle wrap-around case
            if normalizedEnd < normalizedStart {
                if angle >= normalizedStart || angle < normalizedEnd {
                    return slice.index
                }
            } else {
                if angle >= normalizedStart && angle < normalizedEnd {
                    return slice.index
                }
            }
        }

        return nil
    }

    /// Calculate the next slice index in clockwise direction
    /// - Parameters:
    ///   - currentIndex: Current slice index (nil for no selection)
    ///   - itemCount: Total number of items
    /// - Returns: Next slice index
    static func nextSliceClockwise(
        currentIndex: Int?,
        itemCount: Int
    ) -> Int? {
        guard itemCount > 0 else { return nil }

        if let current = currentIndex {
            return (current + 1) % itemCount
        } else {
            return 0
        }
    }

    /// Calculate the next slice index in counter-clockwise direction
    /// - Parameters:
    ///   - currentIndex: Current slice index (nil for no selection)
    ///   - itemCount: Total number of items
    /// - Returns: Previous slice index
    static func nextSliceCounterClockwise(
        currentIndex: Int?,
        itemCount: Int
    ) -> Int? {
        guard itemCount > 0 else { return nil }

        if let current = currentIndex {
            return (current - 1 + itemCount) % itemCount
        } else {
            return itemCount - 1
        }
    }

    /// Calculate selected slice from controller analog stick input
    /// - Parameters:
    ///   - x: Analog stick X value (-1.0 to 1.0)
    ///   - y: Analog stick Y value (-1.0 to 1.0)
    ///   - deadzone: Minimum magnitude to register (default 0.3)
    ///   - slices: Array of slices
    /// - Returns: Index of selected slice, or nil if stick is in deadzone
    static func selectedSlice(
        fromAnalogStick x: Double,
        y: Double,
        deadzone: Double = 0.3,
        slices: [RadialGeometry.Slice]
    ) -> Int? {
        let magnitude = sqrt(x * x + y * y)

        // If stick is in deadzone, no selection
        if magnitude < deadzone {
            return nil
        }

        // Calculate angle from stick position
        // Note: Y is typically inverted on controllers
        let angle = atan2(-y, x)
        let normalizedAngle = RadialGeometry.normalizeAngle(angle)

        return selectedSlice(fromAngle: normalizedAngle, slices: slices)
    }
}
