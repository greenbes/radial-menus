//
//  AccessibilityManagerProtocol.swift
//  radial-menu
//
//  Created by Claude on 11/25/25.
//

import Foundation
import AppKit
import Combine

// MARK: - Protocol

/// Protocol for managing accessibility features
protocol AccessibilityManagerProtocol {
    /// Current system accessibility preferences
    var preferences: AccessibilityPreferences { get }

    /// Publisher for preference changes
    var preferencesPublisher: AnyPublisher<AccessibilityPreferences, Never> { get }

    /// Announce a message to VoiceOver
    func announce(_ message: String, priority: AnnouncementPriority)

    /// Post accessibility notification
    func postNotification(_ notification: NSAccessibility.Notification, element: Any?)

    /// Start observing system accessibility preferences
    func startObserving()

    /// Stop observing
    func stopObserving()
}

// MARK: - Accessibility Preferences

/// Accessibility preferences from system settings
struct AccessibilityPreferences: Equatable {
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let increaseContrast: Bool
    let differentiateWithoutColor: Bool
    let voiceOverEnabled: Bool

    static var current: AccessibilityPreferences {
        AccessibilityPreferences(
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
            differentiateWithoutColor: NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor,
            voiceOverEnabled: NSWorkspace.shared.isVoiceOverEnabled
        )
    }
}

// MARK: - Announcement Priority

/// Priority for VoiceOver announcements
enum AnnouncementPriority {
    case low
    case medium
    case high

    var nsAccessibilityPriority: NSAccessibilityPriorityLevel {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}
