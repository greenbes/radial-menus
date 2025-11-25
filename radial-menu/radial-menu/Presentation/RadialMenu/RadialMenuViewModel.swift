//
//  RadialMenuViewModel.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import Combine
import CoreGraphics
import AppKit

/// ViewModel for the radial menu, coordinating state and actions
final class RadialMenuViewModel: ObservableObject {
    // MARK: - Dependencies

    private let configManager: ConfigurationManagerProtocol
    private let actionExecutor: ActionExecutorProtocol
    private let overlayWindow: OverlayWindowProtocol
    private let accessibilityManager: AccessibilityManagerProtocol?
    private let iconSetProvider: IconSetProviderProtocol

    // MARK: - Published State

    @Published private(set) var menuState: MenuState = .closed
    @Published var selectedIndex: Int? = nil
    @Published private(set) var configuration: MenuConfiguration
    @Published private(set) var hasKeyboardFocus: Bool = true

    // Exposed for View to render slices without recalculating
    @Published private(set) var slices: [RadialGeometry.Slice] = []

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    /// Completion handler for Shortcuts integration - called when menu closes
    /// Returns the selected MenuItem if an action was executed, nil if dismissed
    private var menuCompletionHandler: ((MenuItem?) -> Void)?

    // MARK: - Initialization

    init(
        configManager: ConfigurationManagerProtocol,
        actionExecutor: ActionExecutorProtocol,
        overlayWindow: OverlayWindowProtocol,
        iconSetProvider: IconSetProviderProtocol,
        accessibilityManager: AccessibilityManagerProtocol? = nil
    ) {
        self.configManager = configManager
        self.actionExecutor = actionExecutor
        self.overlayWindow = overlayWindow
        self.iconSetProvider = iconSetProvider
        self.accessibilityManager = accessibilityManager
        self.configuration = configManager.currentConfiguration

        setupConfigurationObserver()
        setupSelectionAnnouncements()
        setupFocusCallback()
    }

    // MARK: - Focus Handling

    private func setupFocusCallback() {
        overlayWindow.setFocusChangeCallback { [weak self] hasFocus in
            self?.hasKeyboardFocus = hasFocus
        }
    }

    // MARK: - Icon Resolution

    /// Resolves the icon for a menu item using the current icon set
    func resolveIcon(for item: MenuItem) -> ResolvedIcon {
        iconSetProvider.resolveIcon(
            iconName: item.iconName,
            iconSetIdentifier: configuration.appearanceSettings.iconSetIdentifier
        )
    }

    // MARK: - Public Methods
    
    var isOpen: Bool {
        switch menuState {
        case .closed:
            return false
        default:
            return true
        }
    }

    func toggleMenu() {
        LogMenu("toggleMenu() called, state: \(menuState)")

        switch menuState {
        case .closed:
            LogMenu("Menu is closed, opening")
            openMenu()
        case .open:
            LogMenu("Menu is open, closing")
            closeMenu()
        default:
            LogMenu("Menu in transition state, ignoring toggle", level: .debug)
            break
        }
    }

    /// Opens the menu and calls completion handler when closed.
    /// - Parameters:
    ///   - position: Optional position to show menu (uses config default if nil)
    ///   - completion: Called when menu closes with the selected item (nil if dismissed)
    func openMenu(at position: CGPoint? = nil, completion: ((MenuItem?) -> Void)? = nil) {
        guard case .closed = menuState else {
            LogMenu("Cannot open menu, not in closed state", level: .debug)
            completion?(nil)
            return
        }

        // Store completion handler for when menu closes
        menuCompletionHandler = completion

        // Clear last selection for Shortcuts polling
        ShortcutsServiceLocator.shared.lastSelectedItemTitle = nil

        LogMenu("Opening menu")
        menuState = .opening
        selectedIndex = nil

        // Calculate slices
        // Window size is dynamic based on radius (radius * 2.2)
        let radius = configuration.appearanceSettings.radius
        let windowSize = radius * 2.2
        let windowCenter = CGPoint(x: windowSize / 2, y: windowSize / 2)

        // Update window size before showing
        overlayWindow.updateWindowSize(forRadius: radius)

        slices = RadialGeometry.calculateSlices(
            itemCount: configuration.items.count,
            radius: radius,
            centerPoint: windowCenter
        )
        LogMenu("Calculated \(slices.count) slices, windowSize=\(windowSize), center=\(windowCenter)", level: .debug)

        // Log slice positions for debugging
        for (index, slice) in slices.enumerated() where index < configuration.items.count {
            LogGeometry("Slice \(index): \(configuration.items[index].title) Y=\(slice.centerPoint.y)")
        }

        // Determine window position based on configuration
        let windowPosition: CGPoint?
        switch configuration.behaviorSettings.positionMode {
        case .center:
            // Center the menu on the main screen
            if let screen = NSScreen.main {
                let screenFrame = screen.frame
                let centerX = screenFrame.origin.x + screenFrame.width / 2
                let centerY = screenFrame.origin.y + screenFrame.height / 2
                windowPosition = CGPoint(x: centerX, y: centerY)
                LogMenu("Using center position mode at \(windowPosition!)", level: .debug)
            } else {
                windowPosition = position
                LogError("No main screen found, using provided position", category: .menu)
            }
        case .atCursor:
            windowPosition = position
            LogMenu("Using cursor position mode", level: .debug)
        case .fixedPosition:
            windowPosition = configuration.behaviorSettings.fixedPosition ?? position
            LogMenu("Using fixed position mode", level: .debug)
        }

        // Show overlay window
        LogMenu("Showing overlay window", level: .debug)
        overlayWindow.show(at: windowPosition)

        // Transition to open state after animation completes
        let animationDuration = configuration.appearanceSettings.animationDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            LogMenu("Transition to open state complete", level: .debug)
            self.menuState = .open(selectedIndex: nil)
            self.announceMenuOpened()
        }
    }

    func closeMenu() {
        closeMenu(withSelectedItem: nil)
    }

    /// Closes the menu, optionally with a selected item result.
    /// - Parameter selectedItem: The item that was selected, or nil if dismissed
    private func closeMenu(withSelectedItem selectedItem: MenuItem?) {
        menuState = .closing
        announceMenuClosed()

        // Capture completion handler before clearing
        let completion = menuCompletionHandler
        menuCompletionHandler = nil

        // Update ShortcutsServiceLocator with selection for polling-based intents
        ShortcutsServiceLocator.shared.lastSelectedItemTitle = selectedItem?.title

        let animationDuration = configuration.appearanceSettings.animationDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.overlayWindow.hide()
            self.menuState = .closed
            self.selectedIndex = nil

            // Call completion handler after menu is fully closed
            completion?(selectedItem)
        }
    }

    func handleMouseMove(at point: CGPoint) {
        guard case .open = menuState else { return }
        guard hasKeyboardFocus else { return }

        let radius = configuration.appearanceSettings.radius
        let windowSize = radius * 2.2
        let center = CGPoint(x: windowSize / 2, y: windowSize / 2)
        let centerRadius = configuration.appearanceSettings.centerRadius

        // Calculate selected slice
        let newSelectedIndex = SelectionCalculator.selectedSlice(
            fromPoint: point,
            center: center,
            centerRadius: centerRadius,
            outerRadius: radius,
            slices: slices
        )

        // Sticky selection: Only update if cursor is over a valid slice
        if let newIndex = newSelectedIndex {
            if newIndex != selectedIndex {
                let angle = RadialGeometry.angleFromCenter(point: point, center: center)
                let degrees = angle * 180.0 / .pi
                let itemName = configuration.items[newIndex].title
                LogMenu("Selection: \(itemName) (slice \(newIndex)) at (\(String(format: "%.0f", point.x)),\(String(format: "%.0f", point.y))) angle=\(String(format: "%.0f", degrees))")
                selectedIndex = newIndex
                menuState = .open(selectedIndex: newIndex)
            }
        }
    }

    func handleMouseClick(at point: CGPoint) {
        let radius = configuration.appearanceSettings.radius
        let windowSize = radius * 2.2
        let center = CGPoint(x: windowSize / 2, y: windowSize / 2)
        let centerRadius = configuration.appearanceSettings.centerRadius

        LogInput("Mouse click at \(point)")

        // Verify we are clicking on a valid slice
        let hitIndex = SelectionCalculator.selectedSlice(
            fromPoint: point,
            center: center,
            centerRadius: centerRadius,
            outerRadius: radius,
            slices: slices
        )

        guard let index = hitIndex, index < configuration.items.count else {
            LogMenu("Click ignored, index: \(String(describing: hitIndex))", level: .debug)
            // Clicked outside valid slice (e.g., center hole), close menu
            closeMenu()
            return
        }

        LogAction("Executing action for index \(index)")
        executeAction(at: index)
    }

    func handleKeyboardNavigation(clockwise: Bool) {
        guard case .open = menuState else { return }

        let itemCount = configuration.items.count
        let newIndex = clockwise ?
            SelectionCalculator.nextSliceClockwise(
                currentIndex: selectedIndex,
                itemCount: itemCount
            ) :
            SelectionCalculator.nextSliceCounterClockwise(
                currentIndex: selectedIndex,
                itemCount: itemCount
            )

        selectedIndex = newIndex
        menuState = .open(selectedIndex: newIndex)
    }

    func handleConfirm() {
        guard case .open(let selected) = menuState,
              let index = selected else {
            return
        }

        executeAction(at: index)
    }

    func handleControllerInput(x: Double, y: Double) {
        guard case .open = menuState else { return }

        let newIndex = SelectionCalculator.selectedSlice(
            fromAnalogStick: x,
            y: y,
            deadzone: configuration.behaviorSettings.joystickDeadzone,
            slices: slices
        )

        // Only update selection if stick is outside deadzone (newIndex != nil)
        // This preserves selection from d-pad or keyboard when stick is at rest
        if let newIndex = newIndex, newIndex != selectedIndex {
            selectedIndex = newIndex
            menuState = .open(selectedIndex: newIndex)
        }
    }

    func handleRightStickInput(x: Double, y: Double) {
        guard case .open = menuState else { return }

        let deadzone = configuration.behaviorSettings.joystickDeadzone
        let magnitude = sqrt(x * x + y * y)

        // Ignore input within deadzone
        guard magnitude >= deadzone else { return }

        // Scale speed based on magnitude (further = faster)
        // Max speed is ~10 points per frame at 60Hz = ~600 points/sec
        let maxSpeed: CGFloat = 10.0
        let speed = CGFloat((magnitude - deadzone) / (1.0 - deadzone)) * maxSpeed

        // Normalize direction and apply speed
        let dx = CGFloat(x / magnitude) * speed
        let dy = CGFloat(y / magnitude) * speed

        overlayWindow.moveWindow(dx: dx, dy: dy)
    }

    func handleDrag(dx: CGFloat, dy: CGFloat) {
        guard case .open = menuState else { return }
        overlayWindow.moveWindow(dx: dx, dy: dy)
    }

    // MARK: - Private Methods

    private func executeAction(at index: Int) {
        guard index < configuration.items.count else { return }

        let item = configuration.items[index]
        menuState = .executing(itemIndex: index)
        announceActionExecuted(for: item)

        actionExecutor.executeAsync(item.action) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                LogAction("Executed successfully: \(item.title)")
            case .failure(let error):
                LogError("Action failed: \(error.localizedDescription)", category: .action)
            }

            // Close menu and report the selected item
            self.closeMenu(withSelectedItem: item)
        }
    }

    private func setupConfigurationObserver() {
        configManager.configurationPublisher
            .sink { [weak self] newConfig in
                guard let self = self else { return }
                let oldRadius = self.configuration.appearanceSettings.radius
                self.configuration = newConfig
                let newRadius = newConfig.appearanceSettings.radius

                // If radius changed and menu is open, update window size and recalculate slices
                if oldRadius != newRadius {
                    LogConfig("Radius changed from \(oldRadius) to \(newRadius)")
                    self.overlayWindow.updateWindowSize(forRadius: newRadius)

                    // Recalculate slices with new radius if menu is open
                    if case .open = self.menuState {
                        let windowSize = newRadius * 2.2
                        let windowCenter = CGPoint(x: windowSize / 2, y: windowSize / 2)
                        self.slices = RadialGeometry.calculateSlices(
                            itemCount: newConfig.items.count,
                            radius: newRadius,
                            centerPoint: windowCenter
                        )
                        LogMenu("Recalculated slices for new radius", level: .debug)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Accessibility

    private func setupSelectionAnnouncements() {
        // Announce selection changes for VoiceOver users
        $selectedIndex
            .dropFirst() // Skip initial nil value
            .removeDuplicates()
            .sink { [weak self] newIndex in
                guard let self = self,
                      let index = newIndex,
                      index < self.configuration.items.count,
                      self.accessibilityManager?.preferences.voiceOverEnabled == true else {
                    return
                }

                let item = self.configuration.items[index]
                let announcement = "\(item.effectiveAccessibilityLabel), \(index + 1) of \(self.configuration.items.count)"
                self.accessibilityManager?.announce(announcement, priority: .medium)
            }
            .store(in: &cancellables)
    }

    private func announceMenuOpened() {
        guard accessibilityManager?.preferences.voiceOverEnabled == true else { return }

        let itemCount = configuration.items.count
        let announcement = "Radial menu opened with \(itemCount) items. Use arrow keys to navigate."
        accessibilityManager?.announce(announcement, priority: .high)
    }

    private func announceMenuClosed() {
        guard accessibilityManager?.preferences.voiceOverEnabled == true else { return }
        accessibilityManager?.announce("Radial menu closed", priority: .low)
    }

    private func announceActionExecuted(for item: MenuItem) {
        guard accessibilityManager?.preferences.voiceOverEnabled == true else { return }
        accessibilityManager?.announce("Activated \(item.effectiveAccessibilityLabel)", priority: .high)
    }
}
