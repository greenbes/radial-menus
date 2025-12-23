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

/// Context for menu navigation (for back button behavior)
enum MenuNavigationContext: Equatable {
    case `default`
    case appSpecific(bundleIdentifier: String)
    case taskSwitcher
}

/// ViewModel for the radial menu, coordinating state and actions
final class RadialMenuViewModel: ObservableObject {
    // MARK: - Dependencies

    private let configManager: ConfigurationManagerProtocol
    private let actionExecutor: ActionExecutorProtocol
    private let overlayWindow: OverlayWindowProtocol
    private let accessibilityManager: AccessibilityManagerProtocol?
    private let iconSetProvider: IconSetProviderProtocol
    private let runningAppProvider: RunningApplicationProviderProtocol
    private let menuProvider: MenuProviderProtocol

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

    /// Whether to skip action execution and just return the selection
    private var returnSelectionOnly = false

    /// Whether the current menu is using an override configuration
    private var isUsingOverrideConfiguration = false

    /// The original configuration to restore after override menu closes
    private var originalConfiguration: MenuConfiguration?

    /// Current menu context (what type of menu is currently displayed)
    private var currentMenuContext: MenuNavigationContext = .default

    /// The bundle ID of the app we're navigating menus for (for ring navigation)
    private var currentAppBundleID: String?

    /// Cache of resolved icons for running apps (by bundle identifier)
    private var taskSwitcherIconCache: [String: ResolvedIcon] = [:]

    // MARK: - Initialization

    init(
        configManager: ConfigurationManagerProtocol,
        actionExecutor: ActionExecutorProtocol,
        overlayWindow: OverlayWindowProtocol,
        iconSetProvider: IconSetProviderProtocol,
        menuProvider: MenuProviderProtocol,
        runningAppProvider: RunningApplicationProviderProtocol = RunningApplicationProvider(),
        accessibilityManager: AccessibilityManagerProtocol? = nil
    ) {
        self.configManager = configManager
        self.actionExecutor = actionExecutor
        self.overlayWindow = overlayWindow
        self.iconSetProvider = iconSetProvider
        self.menuProvider = menuProvider
        self.runningAppProvider = runningAppProvider
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
    /// Special handling for task switcher items and launchApp items which use runtime NSImage icons
    func resolveIcon(for item: MenuItem) -> ResolvedIcon {
        // Check if this is a task switcher item (has activateApp action)
        if case .activateApp(let bundleID) = item.action {
            // Check cache first
            if let cached = taskSwitcherIconCache[bundleID] {
                return cached
            }

            // Get the app icon from the running app
            if let app = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == bundleID }),
               let icon = app.icon {
                let resolved = ResolvedIcon(nsImage: icon, name: bundleID)
                taskSwitcherIconCache[bundleID] = resolved
                return resolved
            }

            // Fallback to generic app icon
            return ResolvedIcon(systemSymbol: "app.fill")
        }

        // Check if this is a launchApp action - show the application's actual icon
        if case .launchApp(let path) = item.action {
            let appIcon = NSWorkspace.shared.icon(forFile: path)
            return ResolvedIcon(nsImage: appIcon, name: path)
        }

        // Default icon resolution via icon set provider
        return iconSetProvider.resolveIcon(
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

    /// Returns the app icon for the current app-specific menu, or nil if not an app-specific menu
    var appSpecificIcon: NSImage? {
        guard case .appSpecific(let bundleID) = currentMenuContext else {
            return nil
        }

        // Try to get icon from running app first
        if let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID }),
           let icon = app.icon {
            return icon
        }

        // Try to get icon from bundle path
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: bundleURL.path)
        }

        return nil
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
        openMenuInternal(at: position, completion: completion)
    }

    /// Opens the menu with a specific configuration (temporary override).
    ///
    /// The original configuration is restored when the menu closes.
    /// Use this for dynamic/ephemeral menus loaded from external sources.
    ///
    /// - Parameters:
    ///   - configuration: The menu configuration to display
    ///   - position: Optional position to show menu (uses config default if nil)
    ///   - returnOnly: If true, returns selected item without executing action
    ///   - completion: Called when menu closes with the selected item (nil if dismissed)
    func openMenu(
        with configuration: MenuConfiguration,
        at position: CGPoint? = nil,
        returnOnly: Bool = false,
        completion: ((MenuItem?) -> Void)? = nil
    ) {
        guard case .closed = menuState else {
            LogMenu("Cannot open menu with override, not in closed state", level: .debug)
            completion?(nil)
            return
        }

        // Store original configuration for restoration
        originalConfiguration = self.configuration
        isUsingOverrideConfiguration = true
        returnSelectionOnly = returnOnly

        // Pre-calculate all values BEFORE setting @Published properties to prevent double-render
        let newRadius = configuration.appearanceSettings.radius
        let windowSize = newRadius * 2.2
        let windowCenter = CGPoint(x: windowSize / 2, y: windowSize / 2)
        let centerRadius = configuration.appearanceSettings.centerRadius
        let newSlices = RadialGeometry.calculateSlices(
            itemCount: configuration.items.count,
            radius: newRadius,
            centerRadius: centerRadius,
            centerPoint: windowCenter
        )

        // Update window size before setting @Published properties
        overlayWindow.updateWindowSize(forRadius: newRadius)

        // Apply configuration and slices together to batch SwiftUI updates
        self.slices = newSlices
        self.configuration = configuration
        LogMenu("Applied override configuration with \(configuration.items.count) items, returnOnly=\(returnOnly)")

        openMenuInternal(at: position, completion: completion)
    }

    /// Internal implementation of menu opening logic.
    private func openMenuInternal(at position: CGPoint?, completion: ((MenuItem?) -> Void)?) {
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

        // Calculate slices (skip if already calculated with correct count - e.g., from openMenu(with:))
        // Window size is dynamic based on radius (radius * 2.2)
        let radius = configuration.appearanceSettings.radius
        let windowSize = radius * 2.2
        let windowCenter = CGPoint(x: windowSize / 2, y: windowSize / 2)

        // Update window size before showing
        overlayWindow.updateWindowSize(forRadius: radius)

        // Only recalculate slices if needed (count mismatch means we need fresh calculation)
        if slices.count != configuration.items.count {
            let centerRadius = configuration.appearanceSettings.centerRadius
            slices = RadialGeometry.calculateSlices(
                itemCount: configuration.items.count,
                radius: radius,
                centerRadius: centerRadius,
                centerPoint: windowCenter
            )
            LogMenu("Calculated \(slices.count) slices, windowSize=\(windowSize), center=\(windowCenter)", level: .debug)
        } else {
            LogMenu("Using pre-calculated \(slices.count) slices", level: .debug)
        }

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

        // Capture override state before clearing
        let wasUsingOverride = isUsingOverrideConfiguration
        let originalConfig = originalConfiguration

        // Clear task switcher cache if needed
        if case .taskSwitcher = currentMenuContext {
            taskSwitcherIconCache.removeAll()
        }

        let animationDuration = configuration.appearanceSettings.animationDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.overlayWindow.hide()
            self.menuState = .closed
            self.selectedIndex = nil

            // Restore original configuration if we were using an override
            if wasUsingOverride, let original = originalConfig {
                self.configuration = original
                LogMenu("Restored original configuration")
            }
            self.isUsingOverrideConfiguration = false
            self.originalConfiguration = nil
            self.returnSelectionOnly = false

            // Reset navigation state
            self.currentMenuContext = .default
            self.currentAppBundleID = nil

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

    func handleRightStickInput(x: Double, y: Double, speedModifier: Double = 0.0) {
        guard case .open = menuState else { return }

        let deadzone = configuration.behaviorSettings.joystickDeadzone
        let magnitude = sqrt(x * x + y * y)

        // Ignore input within deadzone
        guard magnitude >= deadzone else { return }

        // Speed multiplier based on left trigger:
        // - No trigger (0.0) = slow speed (0.1x)
        // - Full trigger (1.0) = fast speed (5.0x)
        let speedMultiplier = 0.1 + 4.9 * speedModifier

        // Scale speed based on magnitude (further = faster)
        // Max speed is ~10 points per frame at 60Hz = ~600 points/sec
        let maxSpeed: CGFloat = 10.0
        let speed = CGFloat((magnitude - deadzone) / (1.0 - deadzone)) * maxSpeed * CGFloat(speedMultiplier)

        // Normalize direction and apply speed
        let dx = CGFloat(x / magnitude) * speed
        let dy = CGFloat(y / magnitude) * speed

        overlayWindow.moveWindow(dx: dx, dy: dy)
    }

    func handleDrag(dx: CGFloat, dy: CGFloat) {
        guard case .open = menuState else { return }
        overlayWindow.moveWindow(dx: dx, dy: dy)
    }

    /// Handles B button / cancel action - closes the menu
    func handleCancel() {
        closeMenu()
    }

    // MARK: - App-Specific Menus

    /// Opens an app-specific menu for the given bundle identifier.
    ///
    /// If an app-specific menu exists for the bundle ID, it is loaded and displayed.
    /// Otherwise, falls back to the default menu.
    ///
    /// - Parameters:
    ///   - bundleIdentifier: The bundle ID of the frontmost application
    ///   - position: Optional position to show menu (uses config default if nil)
    func openAppSpecificMenu(bundleIdentifier: String, at position: CGPoint? = nil) {
        LogMenu("Opening app-specific menu for \(bundleIdentifier), menuState: \(menuState), currentContext: \(currentMenuContext)")

        switch menuState {
        case .open:
            // Ring navigation: if on app-specific, go to default; if on default, go to app-specific
            if case .appSpecific(let currentBundleID) = currentMenuContext, currentBundleID == bundleIdentifier {
                // On app-specific menu, switch to default (ring navigation)
                LogMenu("Ring navigation: switching from app-specific to default")
                transitionToDefaultMenu()
            } else {
                // On default menu, switch to app-specific
                LogMenu("Ring navigation: switching from default to app-specific")
                currentAppBundleID = bundleIdentifier
                transitionToAppSpecificMenu(bundleIdentifier: bundleIdentifier)
            }

        case .closed:
            // Menu is closed, open app-specific menu
            currentAppBundleID = bundleIdentifier
            openAppSpecificMenuInternal(bundleIdentifier: bundleIdentifier, at: position)

        case .opening, .closing, .executing:
            // Menu is in transition, ignore request
            LogMenu("Ignoring app-specific menu request during transition state: \(menuState)")
        }
    }

    /// Transitions from current menu to the default menu (ring navigation)
    private func transitionToDefaultMenu() {
        let currentPosition = overlayWindow.centerPosition

        menuState = .closing
        let animationDuration = configuration.appearanceSettings.animationDuration

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) { [weak self] in
            guard let self = self else { return }

            self.overlayWindow.hide()
            self.menuState = .closed
            self.selectedIndex = nil

            // Restore original configuration if we were using an override
            if self.isUsingOverrideConfiguration, let original = self.originalConfiguration {
                // Pre-calculate all values BEFORE setting @Published properties to prevent double-render
                let newRadius = original.appearanceSettings.radius
                let windowSize = newRadius * 2.2
                let windowCenter = CGPoint(x: windowSize / 2, y: windowSize / 2)
                let centerRadius = original.appearanceSettings.centerRadius
                let newSlices = RadialGeometry.calculateSlices(
                    itemCount: original.items.count,
                    radius: newRadius,
                    centerRadius: centerRadius,
                    centerPoint: windowCenter
                )

                // Update window size before setting @Published properties
                self.overlayWindow.updateWindowSize(forRadius: newRadius)

                // Apply slices and configuration together
                self.slices = newSlices
                self.configuration = original
                LogMenu("Restored original configuration")
            }
            self.isUsingOverrideConfiguration = false
            self.originalConfiguration = nil

            self.currentMenuContext = .default
            self.openMenu(at: currentPosition)
        }
    }

    /// Transitions from current menu to an app-specific menu (ring navigation)
    private func transitionToAppSpecificMenu(bundleIdentifier: String) {
        let currentPosition = overlayWindow.centerPosition

        menuState = .closing
        let animationDuration = configuration.appearanceSettings.animationDuration

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) { [weak self] in
            guard let self = self else { return }

            self.overlayWindow.hide()
            self.menuState = .closed
            self.selectedIndex = nil

            self.openAppSpecificMenuInternal(bundleIdentifier: bundleIdentifier, at: currentPosition)
        }
    }

    /// Internal implementation for opening app-specific menu
    private func openAppSpecificMenuInternal(bundleIdentifier: String, at position: CGPoint?) {
        // Try to resolve the app-specific menu
        let result = menuProvider.resolve(.named(bundleIdentifier))

        switch result {
        case .success(let appMenuConfig):
            LogMenu("Found app-specific menu for \(bundleIdentifier) with \(appMenuConfig.items.count) items")
            currentMenuContext = .appSpecific(bundleIdentifier: bundleIdentifier)
            openMenu(with: appMenuConfig, at: position)

        case .failure(let error):
            // Check if it's just "menu not found" - that's expected, fall back to default
            if case .menuNotFound = error {
                LogMenu("No app-specific menu for \(bundleIdentifier), using default")
            } else if case .fileNotFound = error {
                LogMenu("No app-specific menu file for \(bundleIdentifier), using default")
            } else {
                // Other errors (parse, schema) should be logged
                LogError("Error loading app-specific menu for \(bundleIdentifier): \(error)", category: .menu)
            }

            // Fall back to default menu
            currentMenuContext = .default
            openMenu(at: position)
        }
    }

    /// Navigates to the previous menu in the ring (default ↔ app-specific).
    ///
    /// Ring navigation: LB toggles between default and app-specific menus.
    func returnToPreviousMenu() {
        // Only allow navigation when menu is fully open, not during transitions
        guard case .open = menuState else {
            LogMenu("Ignoring ring navigation, not in open state: \(menuState)")
            return
        }

        // Ring navigation: toggle between default and app-specific
        switch currentMenuContext {
        case .default:
            // On default menu, switch to app-specific (if we have a cached bundle ID)
            if let bundleID = currentAppBundleID {
                LogMenu("Ring navigation (LB): switching from default to app-specific for \(bundleID)")
                transitionToAppSpecificMenu(bundleIdentifier: bundleID)
            } else {
                LogMenu("Ring navigation (LB): no cached app bundle ID, staying on default")
            }

        case .appSpecific:
            // On app-specific menu, switch to default
            LogMenu("Ring navigation (LB): switching from app-specific to default")
            transitionToDefaultMenu()

        case .taskSwitcher:
            // Task switcher is separate from the ring, just close it
            LogMenu("Closing task switcher")
            closeMenu()
        }
    }

    // MARK: - Task Switcher

    /// Builds a MenuConfiguration from currently running applications
    private func buildTaskSwitcherConfiguration() -> MenuConfiguration {
        let apps = runningAppProvider.runningApplications()

        // If no apps running, show a placeholder
        if apps.isEmpty {
            return MenuConfiguration(
                items: [MenuItem(
                    title: "No Apps",
                    iconName: "questionmark.circle",
                    action: .simulateKeyboardShortcut(modifiers: [], key: "escape")
                )],
                appearanceSettings: configuration.appearanceSettings,
                behaviorSettings: configuration.behaviorSettings,
                centerTitle: "No Apps Running"
            )
        }

        // Create menu items for each running app
        let items: [MenuItem] = apps.map { app in
            MenuItem(
                title: app.localizedName,
                iconName: app.bundleIdentifier,  // Used as identifier for icon resolution
                action: .activateApp(bundleIdentifier: app.bundleIdentifier),
                preserveColors: true  // App icons should preserve their colors
            )
        }

        // Calculate radius based on item count to ensure slices remain readable
        // Base radius is 150, scale up for more than 8 items
        let baseRadius = configuration.appearanceSettings.radius
        let scaledRadius = items.count > 8
            ? baseRadius * (Double(items.count) / 8.0)
            : baseRadius

        var appearanceSettings = configuration.appearanceSettings
        appearanceSettings.radius = scaledRadius

        return MenuConfiguration(
            items: items,
            appearanceSettings: appearanceSettings,
            behaviorSettings: configuration.behaviorSettings,
            centerTitle: "Switch App"
        )
    }

    /// Opens the task switcher menu
    private func openTaskSwitcher() {
        LogMenu("Opening task switcher")

        // Capture current menu position before closing
        let currentPosition = overlayWindow.centerPosition

        // Close current menu first
        menuState = .closing

        let animationDuration = configuration.appearanceSettings.animationDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) { [weak self] in
            guard let self = self else { return }

            self.overlayWindow.hide()
            self.menuState = .closed
            self.selectedIndex = nil

            // Build task switcher configuration
            let taskSwitcherConfig = self.buildTaskSwitcherConfiguration()

            // Update current context to task switcher
            self.currentMenuContext = .taskSwitcher

            // Open with the task switcher configuration at the same position
            self.openMenu(with: taskSwitcherConfig, at: currentPosition) { [weak self] _ in
                // Clear icon cache when closed
                self?.taskSwitcherIconCache.removeAll()
            }
        }
    }

    // MARK: - Private Methods

    private func executeAction(at index: Int) {
        guard index < configuration.items.count else { return }

        let item = configuration.items[index]

        // Special handling for task switcher action
        if case .openTaskSwitcher = item.action {
            LogAction("Opening task switcher")
            openTaskSwitcher()
            return
        }

        // Special handling for switchApp internal command
        if case .internalCommand(let command) = item.action, command == .switchApp {
            LogAction("Opening task switcher via internal command")
            openTaskSwitcher()
            return
        }

        menuState = .executing(itemIndex: index)
        announceActionExecuted(for: item)

        // If returnSelectionOnly is set, skip action execution and just return the selection
        if returnSelectionOnly {
            LogAction("Return-only mode: returning '\(item.title)' without executing action")
            closeMenu(withSelectedItem: item)
            return
        }

        actionExecutor.executeAsync(item.action) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                LogAction("Executed successfully: \(item.title)")
            case .failure(let error):
                LogError("Action failed: \(error.localizedDescription)", category: .action)
            }

            // For app-specific menus, keep menu open (sticky behavior)
            // User must press B button or hamburger to close
            if case .appSpecific(_) = self.currentMenuContext {
                LogAction("Keeping app-specific menu open (sticky mode)")
                // Reset to open state with no selection
                self.menuState = .open(selectedIndex: nil)
                self.selectedIndex = nil
            } else {
                // Close menu and report the selected item for default/task switcher menus
                self.closeMenu(withSelectedItem: item)
            }
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
                        let newCenterRadius = newConfig.appearanceSettings.centerRadius
                        self.slices = RadialGeometry.calculateSlices(
                            itemCount: newConfig.items.count,
                            radius: newRadius,
                            centerRadius: newCenterRadius,
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
