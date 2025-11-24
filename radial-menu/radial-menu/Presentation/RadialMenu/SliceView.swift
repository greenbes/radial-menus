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

/// View for a single slice in the radial menu
struct SliceView: View, Equatable {
    let item: MenuItem
    let iconSet: IconSet
    let slice: RadialGeometry.Slice
    let isSelected: Bool
    let radius: Double
    let centerRadius: Double
    
    static func == (lhs: SliceView, rhs: SliceView) -> Bool {
        return lhs.isSelected == rhs.isSelected &&
               lhs.item.id == rhs.item.id &&
               lhs.slice == rhs.slice &&
               lhs.radius == rhs.radius &&
               lhs.centerRadius == rhs.centerRadius &&
               lhs.iconSet == rhs.iconSet
    }

    var body: some View {
        let outerRadius = isSelected ? radius * 1.05 : radius
        let iconOffset = isSelected ? 5.0 : 0.0
        let resolvedIcon = item.resolvedIcon(for: iconSet)

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
                        Log("🎨 \(item.title) rendered at global Y=\(frame.minY) local Y=\(iconY)")
                    }
                }
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var iconColor: Color {
        isSelected ? .white : .orange
    }

    private var sliceColor: Color {
        if isSelected {
            return Color.blue.opacity(0.8)
        } else {
            return Color.gray.opacity(0.6)
        }
    }
}

private extension SliceView {
    func iconImage(for resolved: IconSet.Icon) -> Image {
        resolved.isSystem ? Image(systemName: resolved.name) : Image(resolved.name)
    }

    @ViewBuilder
    func iconView(for resolvedIcon: IconSet.Icon) -> some View {
        let baseImage = iconImage(for: resolvedIcon)

        if resolvedIcon.isSystem {
            // Force monochrome rendering so every symbol uses the same tint rather than the
            // hierarchical palette that caused gray/orange mismatches.
            baseImage
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(iconColor)
                .font(.system(size: 24, weight: .semibold))
        } else {
            // Treat asset images as templates to respect the tint color.
            baseImage
                .renderingMode(.template)
                .foregroundColor(iconColor)
                .font(.system(size: 24, weight: .semibold))
        }
    }
}

// Preview removed in CLI build to avoid macro plugin dependency.
