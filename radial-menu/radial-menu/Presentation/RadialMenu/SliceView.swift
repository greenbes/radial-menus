//
//  SliceView.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import SwiftUI

/// View for a single slice in the radial menu
struct SliceView: View {
    let item: MenuItem
    let slice: RadialGeometry.Slice
    let isSelected: Bool
    let radius: Double
    let centerRadius: Double

    var body: some View {
        ZStack {
            // Slice background (wedge shape)
            SliceShape(
                startAngle: Angle(radians: slice.startAngle),
                endAngle: Angle(radians: slice.endAngle),
                innerRadius: centerRadius,
                outerRadius: radius
            )
            .fill(sliceColor)
            .overlay(
                SliceShape(
                    startAngle: Angle(radians: slice.startAngle),
                    endAngle: Angle(radians: slice.endAngle),
                    innerRadius: centerRadius,
                    outerRadius: radius
                )
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )

            // Icon and label
            VStack(spacing: 4) {
                Image(systemName: item.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)

                Text(item.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .position(slice.centerPoint)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var sliceColor: Color {
        if isSelected {
            return Color.blue.opacity(0.8)
        } else {
            return Color.gray.opacity(0.6)
        }
    }
}

/// Custom shape for a radial slice (wedge)
struct SliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: Double
    let outerRadius: Double

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

#Preview {
    let item = MenuItem.sample()
    let slice = RadialGeometry.Slice(
        index: 0,
        startAngle: -.pi / 2,
        endAngle: 0,
        centerAngle: -.pi / 4,
        centerPoint: CGPoint(x: 250, y: 150)
    )

    SliceView(
        item: item,
        slice: slice,
        isSelected: true,
        radius: 150,
        centerRadius: 40
    )
    .frame(width: 400, height: 400)
    .background(Color.black.opacity(0.1))
}
