//
//  SliceView.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import SwiftUI

/// Custom shape for a radial slice (wedge)
struct SliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: Double
    var outerRadius: Double

    var animatableData: Double {
        get { outerRadius }
        set { outerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Outer arc
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Line to inner arc start
        let innerEndX = center.x + CGFloat(cos(endAngle.radians) * innerRadius)
        let innerEndY = center.y + CGFloat(sin(endAngle.radians) * innerRadius)
        path.addLine(to: CGPoint(x: innerEndX, y: innerEndY))

        // Inner arc (reverse direction)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )

        path.closeSubpath()

        return path
    }
}

/// Shape for just the inner and outer arcs of a slice (no side lines)
struct SliceArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let radius: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        return path
    }
}

/// View for a single slice in the radial menu
struct SliceView: View, Equatable {
    let item: MenuItem
    let resolvedIcon: ResolvedIcon
    let slice: RadialGeometry.Slice
    let isSelected: Bool
    let radius: Double
    let centerRadius: Double
    let foregroundColor: Color
    let selectedItemColor: Color
    let totalItems: Int

    // System accessibility preference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func == (lhs: SliceView, rhs: SliceView) -> Bool {
        return lhs.isSelected == rhs.isSelected &&
               lhs.item.id == rhs.item.id &&
               lhs.item.preserveColors == rhs.item.preserveColors &&
               lhs.slice == rhs.slice &&
               lhs.radius == rhs.radius &&
               lhs.centerRadius == rhs.centerRadius &&
               lhs.resolvedIcon == rhs.resolvedIcon &&
               lhs.foregroundColor == rhs.foregroundColor &&
               lhs.selectedItemColor == rhs.selectedItemColor &&
               lhs.totalItems == rhs.totalItems
    }

    var body: some View {
        let outerRadius = isSelected ? radius * 1.05 : radius
        let iconOffset = isSelected ? 5.0 : 0.0

        // Remove per-frame logging as it's too verbose

        // Calculate icon position with offset
        let midAngle = (slice.startAngle + slice.endAngle) / 2
        let iconX = slice.centerPoint.x + CGFloat(cos(midAngle) * iconOffset)
        let iconY = slice.centerPoint.y + CGFloat(sin(midAngle) * iconOffset)

        ZStack {
            // Slice background (wedge shape)
            SliceShape(
                startAngle: Angle(radians: slice.startAngle),
                endAngle: Angle(radians: slice.endAngle),
                innerRadius: centerRadius,
                outerRadius: outerRadius
            )
            .fill(sliceColor)
            .overlay(
                SliceShape(
                    startAngle: Angle(radians: slice.startAngle),
                    endAngle: Angle(radians: slice.endAngle),
                    innerRadius: centerRadius,
                    outerRadius: outerRadius
                )
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )

            // Thick borders on inner and outer arcs when selected
            if isSelected {
                // Outer arc border
                SliceArcShape(
                    startAngle: Angle(radians: slice.startAngle),
                    endAngle: Angle(radians: slice.endAngle),
                    radius: outerRadius
                )
                .stroke(foregroundColor, lineWidth: 10)

                // Inner arc border
                SliceArcShape(
                    startAngle: Angle(radians: slice.startAngle),
                    endAngle: Angle(radians: slice.endAngle),
                    radius: centerRadius
                )
                .stroke(foregroundColor, lineWidth: 10)
            }

            // Icon and label
            VStack(spacing: 4) {
                iconView(for: resolvedIcon)

                Text(item.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(iconColor)
                    .lineLimit(1)
            }
            .position(x: iconX, y: iconY)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        let frame = geo.frame(in: .global)
                        LogMenu("\(item.title) rendered at globalY=\(frame.minY) localY=\(iconY)", level: .debug)
                    }
                }
            )
        }
        // Respect system reduce motion preference
        .animation(reduceMotion ? nil : .linear(duration: 0.05), value: isSelected)
        // MARK: - Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.effectiveAccessibilityLabel)
        .accessibilityHint(item.effectiveAccessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected, \(slice.index + 1) of \(totalItems)" : "\(slice.index + 1) of \(totalItems)")
        .accessibilityIdentifier("slice-\(item.id)")
    }

    private var iconColor: Color {
        isSelected ? foregroundColor.opacity(1.0) : foregroundColor.opacity(0.7)
    }

    private var sliceColor: Color {
        if isSelected {
            return selectedItemColor
        } else {
            return Color.gray.opacity(0.6)
        }
    }
}

private extension SliceView {
    func iconImage(for resolved: ResolvedIcon) -> Image {
        if resolved.isSystemSymbol {
            return Image(systemName: resolved.name)
        } else if let fileURL = resolved.fileURL {
            // Load from file system (custom icon set)
            if let nsImage = NSImage(contentsOf: fileURL) {
                return Image(nsImage: nsImage)
            }
            // Fallback if file load fails
            return Image(systemName: "questionmark.circle")
        } else if resolved.isAssetCatalog {
            // Asset catalog image (built-in non-system icons like "rainbow")
            return Image(resolved.name)
        } else {
            // Fallback to system symbol
            return Image(systemName: resolved.name)
        }
    }

    @ViewBuilder
    func iconView(for resolved: ResolvedIcon) -> some View {
        let baseImage = iconImage(for: resolved)

        // Determine if colors should be preserved:
        // - Explicit per-item setting takes precedence
        // - ResolvedIcon's preserveColors flag
        // - Asset catalog images preserve colors by default
        let shouldPreserveColors = item.preserveColors || resolved.preserveColors || resolved.isAssetCatalog

        if shouldPreserveColors {
            // Preserve original icon colors (for full-color PDFs/assets)
            baseImage
                .font(.system(size: 24, weight: .semibold))
        } else {
            // Force monochrome rendering so every symbol uses the same tint rather than the
            // hierarchical palette that caused gray/orange mismatches.
            baseImage
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(iconColor)
                .font(.system(size: 24, weight: .semibold))
        }
    }
}

// Preview removed in CLI build to avoid macro plugin dependency.
