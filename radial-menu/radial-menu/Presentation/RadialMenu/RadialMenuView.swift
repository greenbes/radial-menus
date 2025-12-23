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

    // Accessibility focus state for VoiceOver navigation
    @AccessibilityFocusState private var accessibilityFocusedItem: UUID?

    var body: some View {
        let radius = viewModel.configuration.appearanceSettings.radius
        let centerRadius = viewModel.configuration.appearanceSettings.centerRadius
        let backgroundColor = viewModel.configuration.appearanceSettings.backgroundColor.color
        let foregroundColor = viewModel.configuration.appearanceSettings.foregroundColor.color
        let selectedItemColor = viewModel.configuration.appearanceSettings.selectedItemColor.color
        let windowSize: CGFloat = radius * 2.2  // Dynamic window size based on radius
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
                    let resolvedIcon = viewModel.resolveIcon(for: item)
                    SliceView(
                        item: item,
                        resolvedIcon: resolvedIcon,
                        slice: slice,
                        isSelected: isSelected,
                        radius: radius,
                        centerRadius: centerRadius,
                        foregroundColor: foregroundColor,
                        selectedItemColor: selectedItemColor,
                        totalItems: viewModel.configuration.items.count
                    )
                    .equatable() // Only re-render if props change
                    .zIndex(isSelected ? 1 : 0)
                    .accessibilityFocused($accessibilityFocusedItem, equals: item.id)
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

                // Center content: app icon + title for app-specific menus, or title/default icon
                if let appIcon = viewModel.appSpecificIcon {
                    // App-specific menu: show app icon and title
                    VStack(spacing: 4) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: centerRadius * 0.8, height: centerRadius * 0.8)
                        if let title = viewModel.configuration.centerTitle {
                            Text(title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(foregroundColor)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(width: centerRadius * 1.6, height: centerRadius * 1.6)
                    .position(centerPoint)
                } else if let title = viewModel.configuration.centerTitle {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(foregroundColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .frame(width: centerRadius * 1.6, height: centerRadius * 1.6)
                        .position(centerPoint)
                } else {
                    Image(systemName: "circle.grid.cross")
                        .font(.system(size: 20))
                        .foregroundColor(foregroundColor)
                        .position(centerPoint)
                }
            }
            .frame(width: windowSize, height: windowSize)
            .background(Color.clear)
            // Dim when losing keyboard focus
            .opacity(viewModel.hasKeyboardFocus ? 1.0 : 0.65)
            .animation(.easeInOut(duration: 0.15), value: viewModel.hasKeyboardFocus)
            // MARK: - Container Accessibility
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Radial Menu")
            .accessibilityHint("Use arrow keys to navigate, Return to select, Escape to close"),

            menuCenter: centerPoint,
            menuRadius: radius,
            centerRadius: centerRadius,
            slices: viewModel.slices,
            isActive: viewModel.isOpen,
            onMouseMove: { point in viewModel.handleMouseMove(at: point) },
            onMouseClick: { point in viewModel.handleMouseClick(at: point) },
            onKeyboardNavigation: { clockwise in viewModel.handleKeyboardNavigation(clockwise: clockwise) },
            onConfirm: { viewModel.handleConfirm() },
            onCancel: { viewModel.closeMenu() },
            onDrag: { dx, dy in viewModel.handleDrag(dx: dx, dy: dy) }
        )
        // Sync accessibility focus with selection changes
        .onChange(of: viewModel.selectedIndex) { _, newIndex in
            if let newIndex = newIndex, newIndex < viewModel.configuration.items.count {
                accessibilityFocusedItem = viewModel.configuration.items[newIndex].id
            }
        }
        // Sync selection with accessibility focus changes (VoiceOver navigation)
        .onChange(of: accessibilityFocusedItem) { _, newFocusedId in
            guard let focusedId = newFocusedId else { return }
            if let index = viewModel.configuration.items.firstIndex(where: { $0.id == focusedId }) {
                viewModel.selectedIndex = index
            }
        }
        // Set initial focus when menu opens
        .onChange(of: viewModel.isOpen) { _, isOpen in
            if isOpen, let selectedIndex = viewModel.selectedIndex,
               selectedIndex < viewModel.configuration.items.count {
                accessibilityFocusedItem = viewModel.configuration.items[selectedIndex].id
            }
        }
    }
}
