//
//  RadialMenuView.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import SwiftUI

/// Main view for the radial menu overlay
struct RadialMenuView: View {
    @ObservedObject var viewModel: RadialMenuViewModel

    var body: some View {
        let radius = viewModel.configuration.appearanceSettings.radius
        let centerRadius = viewModel.configuration.appearanceSettings.centerRadius
        let backgroundColor = viewModel.configuration.appearanceSettings.backgroundColor.color
        let foregroundColor = viewModel.configuration.appearanceSettings.foregroundColor.color
        let selectedItemColor = viewModel.configuration.appearanceSettings.selectedItemColor.color
        let windowSize: CGFloat = 400.0
        let centerPoint = CGPoint(x: windowSize/2, y: windowSize/2)

        RadialMenuContainer(
            content: ZStack {
                // Background circle with user-selected color
                Circle()
                    .fill(backgroundColor)
                    .frame(width: radius * 2.1, height: radius * 2.1)
                    .position(centerPoint)

                // Render each slice
                ForEach(Array(zip(viewModel.configuration.items, viewModel.slices)), id: \.0.id) { item, slice in
                    let isSelected = slice.index == viewModel.selectedIndex
                    SliceView(
                        item: item,
                        iconSet: viewModel.configuration.appearanceSettings.iconSet,
                        slice: slice,
                        isSelected: isSelected,
                        radius: radius,
                        centerRadius: centerRadius,
                        foregroundColor: foregroundColor,
                        selectedItemColor: selectedItemColor
                    )
                    .equatable() // Only re-render if props change
                    .zIndex(isSelected ? 1 : 0)
                }

                // Center circle
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .overlay(
                        Circle()
                            .stroke(foregroundColor.opacity(0.3), lineWidth: 2)
                    )
                    .position(centerPoint)

                // Center icon
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 20))
                    .foregroundColor(foregroundColor)
                    .position(centerPoint)
            }
            .frame(width: windowSize, height: windowSize)
            .background(Color.clear),
            
            menuCenter: centerPoint,
            menuRadius: radius,
            centerRadius: centerRadius,
            slices: viewModel.slices,
            isActive: viewModel.isOpen,
            onMouseMove: { point in viewModel.handleMouseMove(at: point) },
            onMouseClick: { point in viewModel.handleMouseClick(at: point) },
            onKeyboardNavigation: { clockwise in viewModel.handleKeyboardNavigation(clockwise: clockwise) },
            onConfirm: { viewModel.handleConfirm() },
            onCancel: { viewModel.closeMenu() }
        )
    }
}
