//
//  EventMonitorProtocol.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import CoreGraphics

/// Event type for EventMonitor
enum EventMonitorEventType {
    case mouseMove(location: CGPoint)
    case mouseClick(location: CGPoint)
    case keyDown(keyCode: UInt16)
}

/// Protocol for monitoring mouse and keyboard events
protocol EventMonitorProtocol {
    /// Callback for events
    typealias EventCallback = (EventMonitorEventType) -> Void

    /// Start monitoring events
    /// - Parameter callback: Callback to invoke when events occur
    func startMonitoring(callback: @escaping EventCallback)

    /// Stop monitoring events
    func stopMonitoring()

    /// Check if currently monitoring
    var isMonitoring: Bool { get }
}
