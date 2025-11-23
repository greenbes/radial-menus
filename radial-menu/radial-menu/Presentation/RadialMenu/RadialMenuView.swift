//
//  RadialMenuView.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import SwiftUI

/// Main view for the radial menu overlay
struct RadialMenuView: View {
    var viewModel: RadialMenuViewModel

    var body: some View {
        let radius = viewModel.configuration.appearanceSettings.radius
        let centerRadius = viewModel.configuration.appearanceSettings.centerRadius
        
        RadialMenuContainer(
            content: ZStack {
                // Render each slice
                ForEach(Array(zip(viewModel.configuration.items, viewModel.slices)), id: \.0.id) { item, slice in
                    SliceView(
                        item: item,
                        slice: slice,
                        isSelected: slice.index == viewModel.selectedIndex,
                        radius: radius,
                        centerRadius: centerRadius
                    )
                }

                // Center circle
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .position(x: radius, y: radius)

                // Center icon
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .position(x: radius, y: radius)
            }
            .frame(width: radius * 2, height: radius * 2)
            .background(Color.clear),
            
            menuCenter: CGPoint(x: radius, y: radius),
            menuRadius: radius,
            centerRadius: centerRadius,
            slices: viewModel.slices,
            isActive: viewModel.isOpen,
            onMouseMove: { point in viewModel.handleMouseMove(at: point) },
            onMouseClick: { point in viewModel.handleMouseClick(at: point) }
        )
    }
}

// Preview commented out to avoid dependency injection complexity in CLI build
/*
#Preview {
    RadialMenuView(viewModel: ...)
}
*/
