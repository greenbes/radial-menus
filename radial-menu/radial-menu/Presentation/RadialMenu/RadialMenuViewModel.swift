//
//  RadialMenuViewModel.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import Combine
import CoreGraphics

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
        print("🎯 RadialMenuViewModel: toggleMenu() called, current state: \(menuState)")

        switch menuState {
        case .closed:
            print("🎯 RadialMenuViewModel: Menu is closed, opening...")
            openMenu()
        case .open:
            print("🎯 RadialMenuViewModel: Menu is open, closing...")
            closeMenu()
        default:
            print("🎯 RadialMenuViewModel: Menu in transition state, ignoring toggle")
            break
        }
    }

    func openMenu(at position: CGPoint? = nil) {
        guard case .closed = menuState else {
            print("⚠️  RadialMenuViewModel: Cannot open menu, not in closed state")
            return
        }

        print("🎯 RadialMenuViewModel: Opening menu...")
        menuState = .opening
        selectedIndex = nil

        // Calculate slices
        // The window is 400x400, so the center is (200, 200).
        // Ideally this should be injected, but for v1 we'll align with OverlayWindowController defaults.
        let radius = configuration.appearanceSettings.radius
        let windowCenter = CGPoint(x: 200, y: 200)
        
        slices = RadialGeometry.calculateSlices(
            itemCount: configuration.items.count,
            radius: radius,
            centerPoint: windowCenter
        )
        print("🎯 RadialMenuViewModel: Calculated \(slices.count) slices with center \(windowCenter)")

        // Show overlay window
        print("🎯 RadialMenuViewModel: Showing overlay window...")
        overlayWindow.show(at: position)

        // Transition to open state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            print("🎯 RadialMenuViewModel: Transition to open state complete")
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
        let center = CGPoint(x: 200, y: 200) // Window center
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
                Log("🎯 ViewModel: Selection changed to \(newIndex) (Point: \(point))")
                selectedIndex = newIndex
                menuState = .open(selectedIndex: newIndex)
            }
        } else {
            // Log("🎯 ViewModel: No valid slice selected at \(point)")
        }
    }

    func handleMouseClick(at point: CGPoint) {
        let radius = configuration.appearanceSettings.radius
        let center = CGPoint(x: 200, y: 200) // Window center
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
            deadzone: 0.3,
            slices: slices
        )

        if newIndex != selectedIndex {
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
                self?.configuration = newConfig
            }
            .store(in: &cancellables)
    }
}
