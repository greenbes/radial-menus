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

    // MARK: - Published State

    @Published private(set) var menuState: MenuState = .closed
    @Published private(set) var selectedIndex: Int? = nil
    @Published private(set) var configuration: MenuConfiguration
    
    // Exposed for View to render slices without recalculating
    @Published private(set) var slices: [RadialGeometry.Slice] = []

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        configManager: ConfigurationManagerProtocol,
        actionExecutor: ActionExecutorProtocol,
        overlayWindow: OverlayWindowProtocol
    ) {
        self.configManager = configManager
        self.actionExecutor = actionExecutor
        self.overlayWindow = overlayWindow
        self.configuration = configManager.currentConfiguration

        setupConfigurationObserver()
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
        Log("🎯 RadialMenuViewModel: toggleMenu() called, current state: \(menuState)")

        switch menuState {
        case .closed:
            Log("🎯 RadialMenuViewModel: Menu is closed, opening...")
            openMenu()
        case .open:
            Log("🎯 RadialMenuViewModel: Menu is open, closing...")
            closeMenu()
        default:
            Log("🎯 RadialMenuViewModel: Menu in transition state, ignoring toggle")
            break
        }
    }

    func openMenu(at position: CGPoint? = nil) {
        guard case .closed = menuState else {
            Log("⚠️  RadialMenuViewModel: Cannot open menu, not in closed state")
            return
        }

        Log("🎯 RadialMenuViewModel: Opening menu...")
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
        Log("🎯 RadialMenuViewModel: Calculated \(slices.count) slices with windowSize=\(windowSize) center=\(windowCenter)")
        Log("SLICE LOGGING START")

        if slices.count > 0 {
            Log("Slice 0: \(configuration.items[0].title) Y=\(slices[0].centerPoint.y)")
        }
        if slices.count > 1 {
            Log("Slice 1: \(configuration.items[1].title) Y=\(slices[1].centerPoint.y)")
        }
        if slices.count > 2 {
            Log("Slice 2: \(configuration.items[2].title) Y=\(slices[2].centerPoint.y)")
        }
        if slices.count > 3 {
            Log("Slice 3: \(configuration.items[3].title) Y=\(slices[3].centerPoint.y)")
        }
        if slices.count > 4 {
            Log("Slice 4: \(configuration.items[4].title) Y=\(slices[4].centerPoint.y)")
        }
        if slices.count > 5 {
            Log("Slice 5: \(configuration.items[5].title) Y=\(slices[5].centerPoint.y)")
        }
        if slices.count > 6 {
            Log("Slice 6: \(configuration.items[6].title) Y=\(slices[6].centerPoint.y)")
        }
        if slices.count > 7 {
            Log("Slice 7: \(configuration.items[7].title) Y=\(slices[7].centerPoint.y)")
        }

        Log("SLICE LOGGING END")

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
                Log("🎯 RadialMenuViewModel: Using center position mode at \(windowPosition!)")
            } else {
                windowPosition = position
                Log("⚠️  RadialMenuViewModel: No main screen found, using provided position")
            }
        case .atCursor:
            windowPosition = position
            Log("🎯 RadialMenuViewModel: Using cursor position mode")
        case .fixedPosition:
            windowPosition = configuration.behaviorSettings.fixedPosition ?? position
            Log("🎯 RadialMenuViewModel: Using fixed position mode")
        }

        // Show overlay window
        Log("🎯 RadialMenuViewModel: Showing overlay window...")
        overlayWindow.show(at: windowPosition)

        // Transition to open state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Log("🎯 RadialMenuViewModel: Transition to open state complete")
            self.menuState = .open(selectedIndex: nil)
        }
    }

    func closeMenu() {
        menuState = .closing

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.overlayWindow.hide()
            self.menuState = .closed
            self.selectedIndex = nil
        }
    }

    func handleMouseMove(at point: CGPoint) {
        guard case .open = menuState else { return }

        let radius = configuration.appearanceSettings.radius
        let windowSize = radius * 2.2
        let center = CGPoint(x: windowSize / 2, y: windowSize / 2)
        let centerRadius = configuration.appearanceSettings.centerRadius

        // Log("🖱️ ViewModel: handleMouseMove at \(point), Center: \(center), Radius: \(radius)")

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
                Log("🎯 Selection changed: \(itemName) (slice \(newIndex)) at point(\(String(format: "%.0f", point.x)),\(String(format: "%.0f", point.y))) angle=\(String(format: "%.0f", degrees))°")
                selectedIndex = newIndex
                menuState = .open(selectedIndex: newIndex)
            }
        } else {
            // Log("🎯 ViewModel: No valid slice selected at \(point)")
        }
    }

    func handleMouseClick(at point: CGPoint) {
        let radius = configuration.appearanceSettings.radius
        let windowSize = radius * 2.2
        let center = CGPoint(x: windowSize / 2, y: windowSize / 2)
        let centerRadius = configuration.appearanceSettings.centerRadius
        
        Log("🖱️ ViewModel: handleMouseClick at \(point)")

        // Verify we are clicking on a valid slice
        let hitIndex = SelectionCalculator.selectedSlice(
            fromPoint: point,
            center: center,
            centerRadius: centerRadius,
            outerRadius: radius,
            slices: slices
        )
        
        guard let index = hitIndex, index < configuration.items.count else {
            Log("❌ ViewModel: Click ignored (Index: \(String(describing: hitIndex)))")
            // Clicked outside valid slice (e.g., center hole), close menu
            closeMenu()
            return
        }

        Log("✅ ViewModel: Executing action for index \(index)")
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

    // MARK: - Private Methods

    private func executeAction(at index: Int) {
        guard index < configuration.items.count else { return }

        let item = configuration.items[index]
        menuState = .executing(itemIndex: index)

        actionExecutor.executeAsync(item.action) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                print("Action executed successfully: \(item.title)")
            case .failure(let error):
                print("Action failed: \(error.localizedDescription)")
            }

            self.closeMenu()
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
                    Log("🎯 RadialMenuViewModel: Radius changed from \(oldRadius) to \(newRadius)")
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
                        Log("🎯 RadialMenuViewModel: Recalculated slices for new radius")
                    }
                }
            }
            .store(in: &cancellables)
    }
}
