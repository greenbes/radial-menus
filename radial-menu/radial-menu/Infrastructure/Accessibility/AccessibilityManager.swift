//
//  AccessibilityManager.swift
//  radial-menu
//
//  Created by Claude on 11/25/25.
//

import Foundation
import AppKit
import Combine

/// Manages accessibility features and system preference observation
final class AccessibilityManager: AccessibilityManagerProtocol {
    private var cancellables = Set<AnyCancellable>()
    private let preferencesSubject = CurrentValueSubject<AccessibilityPreferences, Never>(.current)

    var preferences: AccessibilityPreferences {
        preferencesSubject.value
    }

    var preferencesPublisher: AnyPublisher<AccessibilityPreferences, Never> {
        preferencesSubject.eraseToAnyPublisher()
    }

    // MARK: - Lifecycle

    func startObserving() {
        // Observe system accessibility preference changes
        NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        )
        .sink { [weak self] _ in
            self?.preferencesSubject.send(.current)
            LogAccessibility("System accessibility preferences changed")
        }
        .store(in: &cancellables)

        // Initial update
        preferencesSubject.send(.current)
        LogAccessibility("Started observing accessibility preferences: reduceMotion=\(preferences.reduceMotion), voiceOver=\(preferences.voiceOverEnabled)")
    }

    func stopObserving() {
        cancellables.removeAll()
        LogAccessibility("Stopped observing accessibility preferences")
    }

    // MARK: - Announcements

    func announce(_ message: String, priority: AnnouncementPriority) {
        LogAccessibility("Announcing: \"\(message)\" (priority: \(priority))")

        // Post with slight delay to avoid conflicts with system announcements
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSAccessibility.post(
                element: NSApp.mainWindow as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: message,
                    .priority: priority.nsAccessibilityPriority.rawValue
                ]
            )
        }
    }

    // MARK: - Notifications

    func postNotification(_ notification: NSAccessibility.Notification, element: Any?) {
        LogAccessibility("Posting notification: \(notification)")

        if let element = element {
            NSAccessibility.post(element: element, notification: notification)
        } else if let window = NSApp.mainWindow {
            NSAccessibility.post(element: window, notification: notification)
        }
    }
}
