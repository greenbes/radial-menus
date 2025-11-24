//
//  RadialGeometry.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import CoreGraphics

/// Pure functions for radial menu geometry calculations
enum RadialGeometry {
    /// Represents a slice in the radial menu
    struct Slice: Equatable {
        let index: Int
        let startAngle: Double
        let endAngle: Double
        let centerAngle: Double
        let centerPoint: CGPoint
    }

    /// Calculate the slices for a radial menu
    /// - Parameters:
    ///   - itemCount: Number of items in the menu
    ///   - radius: Radius of the menu
    ///   - centerPoint: Center point of the menu
    /// - Returns: Array of Slice objects
    static func calculateSlices(
        itemCount: Int,
        radius: Double,
        centerPoint: CGPoint
    ) -> [Slice] {
        guard itemCount > 0 else { return [] }

        let anglePerSlice = 2.0 * .pi / Double(itemCount)
        let startOffset = -.pi / 2.0  // Start at top (12 o'clock)

        return (0..<itemCount).map { index in
            let startAngle = startOffset + anglePerSlice * Double(index)
            let endAngle = startAngle + anglePerSlice
            let centerAngle = startAngle + anglePerSlice / 2.0

            let centerX = centerPoint.x + CGFloat(cos(centerAngle) * radius * 0.65)
            let centerY = centerPoint.y - CGFloat(sin(centerAngle) * radius * 0.65) // Flipped Y for SwiftUI

            return Slice(
                index: index,
                startAngle: startAngle,
                endAngle: endAngle,
                centerAngle: centerAngle,
                centerPoint: CGPoint(x: centerX, y: centerY)
            )
        }
    }

    /// Calculate the angle from center to a point
    /// - Parameters:
    ///   - point: The point to measure
    ///   - center: The center point
    /// - Returns: Angle in radians
    static func angleFromCenter(point: CGPoint, center: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return atan2(Double(dy), Double(dx))
    }

    /// Calculate the distance between two points
    /// - Parameters:
    ///   - point1: First point
    ///   - point2: Second point
    /// - Returns: Distance
    static func distance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(Double(dx * dx + dy * dy))
    }

    /// Normalize an angle to be between 0 and 2π
    /// - Parameter angle: Angle in radians
    /// - Returns: Normalized angle
    static func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized < 0 {
            normalized += 2.0 * .pi
        }
        while normalized >= 2.0 * .pi {
            normalized -= 2.0 * .pi
        }
        return normalized
    }
}
