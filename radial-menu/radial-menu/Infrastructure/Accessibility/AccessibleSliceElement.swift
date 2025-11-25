//
//  AccessibleSliceElement.swift
//  radial-menu
//
//  Created by Claude on 11/25/25.
//

import AppKit

/// NSAccessibilityElement representing a single slice in the radial menu
/// Used for VoiceOver and other assistive technologies to interact with menu items
final class AccessibleSliceElement: NSAccessibilityElement {
    let item: MenuItem
    let slice: RadialGeometry.Slice
    var isSelected: Bool
    var totalItems: Int

    weak var parentElement: NSAccessibilityElement?
    var onActivate: ((Int) -> Void)?

    init(item: MenuItem, slice: RadialGeometry.Slice, isSelected: Bool, totalItems: Int) {
        self.item = item
        self.slice = slice
        self.isSelected = isSelected
        self.totalItems = totalItems
        super.init()
    }

    // MARK: - NSAccessibilityElement Overrides

    override func accessibilityRole() -> NSAccessibility.Role? {
        return .button
    }

    override func accessibilityRoleDescription() -> String? {
        return "menu item"
    }

    override func accessibilityLabel() -> String? {
        return item.effectiveAccessibilityLabel
    }

    override func accessibilityHelp() -> String? {
        return item.effectiveAccessibilityHint
    }

    override func accessibilityValue() -> Any? {
        if isSelected {
            return "Selected, \(slice.index + 1) of \(totalItems)"
        }
        return "\(slice.index + 1) of \(totalItems)"
    }

    override func isAccessibilitySelected() -> Bool {
        return isSelected
    }

    override func accessibilityIndex() -> Int {
        return slice.index
    }

    override func accessibilityParent() -> Any? {
        return parentElement
    }

    override func isAccessibilityElement() -> Bool {
        return true
    }

    override func accessibilityFrame() -> NSRect {
        // Return frame around the slice center point
        // This is an approximate hit area for accessibility purposes
        let size: CGFloat = 60
        return NSRect(
            x: slice.centerPoint.x - size / 2,
            y: slice.centerPoint.y - size / 2,
            width: size,
            height: size
        )
    }

    override func accessibilityPerformPress() -> Bool {
        LogAccessibility("AccessibleSliceElement: performPress for slice \(slice.index)")
        onActivate?(slice.index)
        return true
    }
}
