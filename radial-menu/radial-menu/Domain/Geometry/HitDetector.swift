//
//  HitDetector.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import CoreGraphics

/// Pure functions for hit detection in the radial menu
enum HitDetector {
    /// Result of a hit test
    enum HitResult: Equatable {
        case outside
        case inCenter
        case inSlice(index: Int)
    }

    /// Determine if a point hits the radial menu and which slice
    /// - Parameters:
    ///   - point: The point to test
    ///   - center: Center of the radial menu
    ///   - radius: Outer radius of the menu
    ///   - centerRadius: Inner radius (center circle)
    ///   - slices: Array of slices
    /// - Returns: Hit result
    static func hitTest(
        point: CGPoint,
        center: CGPoint,
        radius: Double,
        centerRadius: Double,
        slices: [RadialGeometry.Slice]
    ) -> HitResult {
        let distance = RadialGeometry.distance(from: center, to: point)

        // Outside the menu entirely
        if distance > radius {
            return .outside
        }

        // In the center circle
        if distance < centerRadius {
            return .inCenter
        }

        // In one of the slices
        let angle = RadialGeometry.angleFromCenter(point: point, center: center)
        let normalizedAngle = RadialGeometry.normalizeAngle(angle)

        for slice in slices {
            if isAngleInSlice(normalizedAngle, slice: slice) {
                return .inSlice(index: slice.index)
            }
        }

        // Fallback (shouldn't happen if geometry is correct)
        return .outside
    }

    /// Check if an angle falls within a slice's angular range
    /// - Parameters:
    ///   - angle: The angle to test (normalized to 0...2π)
    ///   - slice: The slice to test against
    /// - Returns: True if the angle is in the slice
    private static func isAngleInSlice(
        _ angle: Double,
        slice: RadialGeometry.Slice
    ) -> Bool {
        let normalizedStart = RadialGeometry.normalizeAngle(slice.startAngle)
        let normalizedEnd = RadialGeometry.normalizeAngle(slice.endAngle)

        // Handle wrap-around case (slice crosses 0 degrees)
        if normalizedEnd < normalizedStart {
            return angle >= normalizedStart || angle < normalizedEnd
        } else {
            return angle >= normalizedStart && angle < normalizedEnd
        }
    }

    /// Determine if a point is anywhere inside the radial menu (including center)
    /// - Parameters:
    ///   - point: The point to test
    ///   - center: Center of the radial menu
    ///   - radius: Outer radius of the menu
    /// - Returns: True if inside the menu
    static func isInsideMenu(
        point: CGPoint,
        center: CGPoint,
        radius: Double
    ) -> Bool {
        let distance = RadialGeometry.distance(from: center, to: point)
        return distance <= radius
    }
}
