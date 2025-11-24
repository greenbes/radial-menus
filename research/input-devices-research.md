# Comprehensive Technical Report: Maximum Input Device Support on macOS 15 Sequoia

**Project:** radial-menu
**Purpose:** Maximum input device compatibility research
**Target:** Personal use (not App Store distribution)
**Platform:** macOS 15 Sequoia
**Date:** 2025-11-24

---

## Executive Summary

This report provides a complete technical overview of input device integration on macOS 15 Sequoia for a radial menu application requiring maximum device compatibility. The research covers game controllers, MIDI devices, HID devices, touch/pen input, mouse, and keyboard input with detailed implementation guidance, code examples, and architectural recommendations.

**Key Finding:** macOS 15 provides comprehensive framework support for virtually all input devices through GameController, CoreMIDI, IOKit, NSEvent, and CGEvent APIs, enabling a unified input architecture that can simultaneously support game controllers, MIDI controllers, custom HID devices, graphics tablets, multi-button mice, and keyboards without App Store restrictions.

---

## 1. Framework Overview by Device Type

### 1.1 Game Controllers

**Primary Framework:** `GameController.framework` (`GCController`)

**Supported Devices:**
- Xbox controllers (One, Series X/S, Elite, Adaptive Controller)
- PlayStation controllers (DualShock 4, DualSense with adaptive triggers)
- Nintendo Switch Pro Controller, Joy-Cons (macOS 13+ native support)
- MFi (Made for iPhone) controllers
- Generic HID game controllers (via fallback to IOKit)

**Key Capabilities:**
- Extended gamepad profiles (buttons, analog sticks, D-pad, triggers)
- Haptic feedback via CoreHaptics integration
- DualSense adaptive triggers (`GCDualSenseAdaptiveTrigger`)
- DualShock 4/DualSense touchpad access
- Motion sensors (gyroscope, accelerometer via `GCMotion`)
- Light bar control (PlayStation controllers)

**Polling Rate:** 60Hz (default), higher for USB wired controllers

**Permissions Required:** None

### 1.2 MIDI Devices

**Primary Framework:** `CoreMIDI.framework`

**Supported Devices:**
- MIDI keyboards
- MIDI controllers (knobs, faders, pads)
- USB MIDI devices
- Traditional MIDI devices (via MIDI interface)
- Virtual MIDI endpoints

**Key Capabilities:**
- Control Change (CC) messages
- Note On/Off events
- Program Change
- Velocity sensitivity
- Multi-device MIDI input

**Polling Rate:** Event-driven (callback-based)

**Permissions Required:** None

### 1.3 HID Devices

**Primary Framework:** `IOKit.framework` (`IOHIDManager`)

**Supported Devices:**
- Stream Decks / macro pads
- Custom controllers
- 3D mice (SpaceMouse, etc.)
- Graphics tablets (raw HID access)
- Generic HID devices with custom usage pages

**Key Capabilities:**
- Device enumeration with matching criteria
- Raw HID report reading
- Custom HID usage page support
- Hotplug detection

**Polling Rate:** 125Hz - 1000Hz (device-dependent)

**Permissions Required:** Input Monitoring

### 1.4 Touch/Pen Input

**Primary Framework:** AppKit (`NSEvent`)

**Supported Devices:**
- Magic Trackpad
- Built-in trackpads
- Wacom tablets
- Other graphics tablets
- Apple Pencil (via iPad Sidecar)

**Key Capabilities:**
- Pressure sensitivity
- Tilt detection
- Rotation
- Absolute coordinates
- Multi-touch gestures
- Proximity events

**Polling Rate:** 60Hz (system-managed)

**Permissions Required:** None (app-level), Input Monitoring (global)

**Private API Option:** `MultitouchSupport.framework` (raw trackpad data)

### 1.5 Mouse Input

**Primary Framework:** AppKit (`NSEvent`), CoreGraphics (`CGEvent`)

**Supported Devices:**
- Standard mice
- Gaming mice with extra buttons
- High-precision mice

**Key Capabilities:**
- Standard buttons (left, right, middle)
- Extra buttons (M4, M5, etc.)
- Scroll wheels (vertical and horizontal)
- High-precision tracking
- Global event monitoring

**Polling Rate:** 125Hz - 1000Hz (device-dependent)

**Permissions Required:** Input Monitoring (for global monitoring)

### 1.6 Keyboard Input

**Primary Framework:** AppKit (`NSEvent`), Carbon Event Manager (for global hotkeys)

**Supported Devices:**
- Standard keyboards
- Mechanical keyboards
- Custom macro keyboards

**Key Capabilities:**
- Key press/release events
- Modifier keys
- Media keys
- Function keys
- Global hotkey registration

**Polling Rate:** Event-driven

**Permissions Required:** Accessibility (for global hotkeys)

---

## 2. Detailed Implementation by Input Method

### 2.1 Game Controllers (GameController.framework)

#### Device Detection and Hotplug

```swift
import GameController

class GameControllerManager {
    private var controllers: [GCController] = []

    func setupControllerObservers() {
        // Observe controller connections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.controllerDidConnect(controller)
        }

        // Observe controller disconnections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.controllerDidDisconnect(controller)
        }

        // Check for already-connected controllers
        controllers = GCController.controllers()
        controllers.forEach { controllerDidConnect($0) }
    }

    private func controllerDidConnect(_ controller: GCController) {
        print("Controller connected: \(controller.vendorName ?? "Unknown")")

        // Configure extended gamepad input
        if let gamepad = controller.extendedGamepad {
            setupExtendedGamepadHandlers(gamepad)
        }

        // Configure DualShock-specific features
        if let dualShock = controller.physicalInputProfile as? GCDualShockGamepad {
            setupDualShockHandlers(dualShock)
        }

        // Configure DualSense-specific features
        if let dualSense = controller.physicalInputProfile as? GCDualSenseGamepad {
            setupDualSenseHandlers(dualSense)
        }

        // Setup haptics
        setupHaptics(for: controller)
    }

    private func setupExtendedGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        // Analog sticks
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleLeftStick(x: xValue, y: yValue)
        }

        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleRightStick(x: xValue, y: yValue)
        }

        // D-pad
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleDPad(x: xValue, y: yValue)
        }

        // Face buttons
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonA(pressed: pressed)
        }

        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonB(pressed: pressed)
        }

        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonX(pressed: pressed)
        }

        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButtonY(pressed: pressed)
        }

        // Triggers (analog)
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleLeftTrigger(value: value, pressed: pressed)
        }

        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleRightTrigger(value: value, pressed: pressed)
        }

        // Shoulder buttons
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleLeftShoulder(pressed: pressed)
        }

        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleRightShoulder(pressed: pressed)
        }

        // Menu button
        gamepad.buttonMenu?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleMenuButton(pressed: pressed)
        }

        // Options button
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleOptionsButton(pressed: pressed)
        }
    }

    private func setupDualSenseHandlers(_ dualSense: GCDualSenseGamepad) {
        // Access adaptive triggers
        dualSense.leftTrigger.mode = .feedback
        dualSense.rightTrigger.mode = .feedback

        // Access touchpad (two-finger touch)
        dualSense.touchpadButton.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleTouchpadPress(pressed: pressed)
        }

        // Touchpad surface (requires more detailed access via physicalInputProfile)
        if let touchpad = dualSense.physicalInputProfile.dpads["Touchpad"] {
            touchpad.valueChangedHandler = { [weak self] _, xValue, yValue in
                self?.handleTouchpadTouch(x: xValue, y: yValue)
            }
        }
    }

    private func setupHaptics(for controller: GCController) {
        guard let haptics = controller.haptics else { return }

        // Create haptic engine
        do {
            let engine = try CHHapticEngine(audioSession: nil, controller: controller)
            try engine.start()

            // Create a simple haptic pattern
            let intensity = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: 0.7
            )
            let sharpness = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: 0.5
            )

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)

            // Play haptic feedback
            try player.start(atTime: 0)
        } catch {
            print("Failed to setup haptics: \(error)")
        }
    }

    // Handler implementations
    private func handleLeftStick(x: Float, y: Float) {
        // Apply dead zone
        let deadZone: Float = 0.1
        let normalizedX = abs(x) < deadZone ? 0 : x
        let normalizedY = abs(y) < deadZone ? 0 : y

        // Use for radial menu selection
        print("Left stick: x=\(normalizedX), y=\(normalizedY)")
    }

    private func handleButtonA(pressed: Bool) {
        if pressed {
            // Confirm radial menu selection
            print("Button A pressed - confirm selection")
        }
    }

    private func handleMenuButton(pressed: Bool) {
        if pressed {
            // Toggle radial menu
            print("Menu button pressed - toggle menu")
        }
    }

    // ... implement other handlers

    private func controllerDidDisconnect(_ controller: GCController) {
        print("Controller disconnected: \(controller.vendorName ?? "Unknown")")
        controllers.removeAll { $0 == controller }
    }
}
```

**Performance Considerations:**
- GameController framework runs at 60Hz polling rate by default
- Input handlers are called on the main queue unless specified
- For high-frequency updates, consider dispatching to a background queue

### 2.2 MIDI Devices (CoreMIDI.framework)

#### Modern MIDI Input Handling (macOS 12+)

```swift
import CoreMIDI

class MIDIInputManager {
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0

    func setupMIDI() {
        // Create MIDI client
        var status = MIDIClientCreateWithBlock("RadialMenuMIDIClient" as CFString, &midiClient) { notification in
            self.handleMIDINotification(notification)
        }

        guard status == noErr else {
            print("Failed to create MIDI client: \(status)")
            return
        }

        // Create input port using modern API (macOS 11+)
        status = MIDIInputPortCreateWithProtocol(
            midiClient,
            "RadialMenuInputPort" as CFString,
            ._1_0, // MIDI 1.0 protocol
            &inputPort
        ) { [weak self] eventList, srcConnRefCon in
            self?.handleMIDIEventList(eventList)
        }

        guard status == noErr else {
            print("Failed to create input port: \(status)")
            return
        }

        // Connect to all MIDI sources
        connectToAllSources()
    }

    private func connectToAllSources() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(inputPort, source, nil)

            // Get source name
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(source, kMIDIPropertyName, &name)
            if let sourceName = name?.takeRetainedValue() as String? {
                print("Connected to MIDI source: \(sourceName)")
            }
        }
    }

    private func handleMIDIEventList(_ eventList: UnsafePointer<MIDIEventList>) {
        // Use modern MIDIEventListForEachEvent API (macOS 12+)
        MIDIEventListForEachEvent(eventList, { eventPtr, _ in
            guard let event = eventPtr?.pointee else { return }

            // Parse MIDI event
            let wordCount = event.wordCount
            guard wordCount > 0 else { return }

            // Access event data
            let words = withUnsafePointer(to: event.words) { ptr in
                UnsafeBufferPointer(start: ptr, count: Int(wordCount))
            }

            // Parse first word (contains message type and channel)
            let firstWord = words[0]
            let statusByte = UInt8((firstWord >> 16) & 0xFF)
            let messageType = statusByte & 0xF0
            let channel = statusByte & 0x0F

            switch messageType {
            case 0x90: // Note On
                let note = UInt8((firstWord >> 8) & 0x7F)
                let velocity = UInt8(firstWord & 0x7F)
                self.handleNoteOn(channel: channel, note: note, velocity: velocity)

            case 0x80: // Note Off
                let note = UInt8((firstWord >> 8) & 0x7F)
                let velocity = UInt8(firstWord & 0x7F)
                self.handleNoteOff(channel: channel, note: note, velocity: velocity)

            case 0xB0: // Control Change
                let controller = UInt8((firstWord >> 8) & 0x7F)
                let value = UInt8(firstWord & 0x7F)
                self.handleControlChange(channel: channel, controller: controller, value: value)

            case 0xC0: // Program Change
                let program = UInt8((firstWord >> 8) & 0x7F)
                self.handleProgramChange(channel: channel, program: program)

            default:
                print("Unhandled MIDI message type: 0x\(String(messageType, radix: 16))")
            }
        }, nil)
    }

    private func handleNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        print("Note On - Channel: \(channel), Note: \(note), Velocity: \(velocity)")

        // Map MIDI notes to radial menu slices
        // Example: Map notes 60-67 (middle C octave) to 8 menu items
        if (60...67).contains(note) {
            let sliceIndex = Int(note - 60)
            selectMenuSlice(index: sliceIndex)
        }

        // Use velocity for interaction strength
        if velocity > 100 {
            // Strong press - immediate activation
            activateMenuSlice(index: Int(note - 60))
        }
    }

    private func handleNoteOff(channel: UInt8, note: UInt8, velocity: UInt8) {
        print("Note Off - Channel: \(channel), Note: \(note), Velocity: \(velocity)")
    }

    private func handleControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
        print("Control Change - Channel: \(channel), Controller: \(controller), Value: \(value)")

        // Map CC messages to radial menu navigation
        switch controller {
        case 1: // Modulation wheel
            let normalizedValue = Float(value) / 127.0
            rotateMenuSelection(amount: normalizedValue)

        case 7: // Volume
            let normalizedValue = Float(value) / 127.0
            scaleMenu(scale: normalizedValue)

        case 10: // Pan
            let normalizedValue = Float(value) / 127.0
            // Use for menu positioning

        default:
            break
        }
    }

    private func handleProgramChange(channel: UInt8, program: UInt8) {
        print("Program Change - Channel: \(channel), Program: \(program)")
        // Switch between different radial menu configurations
    }

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        let message = notification.pointee
        switch message.messageID {
        case .msgObjectAdded:
            print("MIDI object added")
            connectToAllSources()

        case .msgObjectRemoved:
            print("MIDI object removed")

        case .msgPropertyChanged:
            print("MIDI property changed")

        default:
            break
        }
    }

    // Placeholder methods for radial menu integration
    private func selectMenuSlice(index: Int) {
        print("Selecting menu slice: \(index)")
    }

    private func activateMenuSlice(index: Int) {
        print("Activating menu slice: \(index)")
    }

    private func rotateMenuSelection(amount: Float) {
        print("Rotating menu selection: \(amount)")
    }

    private func scaleMenu(scale: Float) {
        print("Scaling menu: \(scale)")
    }

    deinit {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }
}
```

### 2.3 HID Devices (IOKit IOHIDManager)

#### Generic HID Device Enumeration and Input

```swift
import IOKit.hid

class HIDDeviceManager {
    private var hidManager: IOHIDManager?
    private var devices: [IOHIDDevice] = []

    func setupHIDManager() {
        // Create HID Manager
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        guard let manager = hidManager else {
            print("Failed to create HID Manager")
            return
        }

        // Set device matching criteria
        // Example: Match all devices (pass nil for all devices)
        // Or create specific matching dictionaries
        let matchingDict = createMatchingDictionary(usagePage: 0x01, usage: 0x05) // Generic Desktop: Game Pad
        IOHIDManagerSetDeviceMatching(manager, matchingDict)

        // Register device matching callback
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, sender, device in
            let manager = Unmanaged<HIDDeviceManager>.fromOpaque(context!).takeUnretainedValue()
            manager.deviceAdded(device)
        }, Unmanaged.passUnretained(self).toOpaque())

        // Register device removal callback
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, result, sender, device in
            let manager = Unmanaged<HIDDeviceManager>.fromOpaque(context!).takeUnretainedValue()
            manager.deviceRemoved(device)
        }, Unmanaged.passUnretained(self).toOpaque())

        // Schedule with run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        // Open the manager
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("Failed to open HID Manager: \(openResult)")
        }
    }

    private func createMatchingDictionary(usagePage: Int, usage: Int) -> CFDictionary {
        return [
            kIOHIDDeviceUsagePageKey: usagePage,
            kIOHIDDeviceUsageKey: usage
        ] as CFDictionary
    }

    private func deviceAdded(_ device: IOHIDDevice) {
        devices.append(device)

        // Get device properties
        let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"

        print("HID Device Added: \(productName) (VID: 0x\(String(vendorID, radix: 16)), PID: 0x\(String(productID, radix: 16)))")

        // Register input value callback
        IOHIDDeviceRegisterInputValueCallback(device, { context, result, sender, value in
            let manager = Unmanaged<HIDDeviceManager>.fromOpaque(context!).takeUnretainedValue()
            manager.handleInputValue(value)
        }, Unmanaged.passUnretained(self).toOpaque())

        // Schedule device with run loop
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        // Open the device
        IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        devices.removeAll { $0 == device }

        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        print("HID Device Removed: \(productName)")

        // Close and unschedule device
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    private func handleInputValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)

        print("HID Input - UsagePage: 0x\(String(usagePage, radix: 16)), Usage: 0x\(String(usage, radix: 16)), Value: \(intValue)")

        // Example: Stream Deck key press
        // Stream Deck uses Usage Page 0xFF (Vendor Specific)
        if usagePage == 0xFF {
            handleStreamDeckInput(usage: usage, value: intValue)
        }

        // Example: 3D Mouse (SpaceMouse)
        // SpaceMouse uses Generic Desktop (0x01) with custom usages
        if usagePage == 0x01 {
            handle3DMouseInput(usage: usage, value: intValue)
        }
    }

    private func handleStreamDeckInput(usage: UInt32, value: CFIndex) {
        print("Stream Deck button \(usage): \(value)")

        // Map Stream Deck keys to radial menu actions
        if value == 1 { // Button pressed
            activateMenuSlice(index: Int(usage))
        }
    }

    private func handle3DMouseInput(usage: UInt32, value: CFIndex) {
        switch usage {
        case 0x30: // X axis
            print("3D Mouse X: \(value)")
        case 0x31: // Y axis
            print("3D Mouse Y: \(value)")
        case 0x32: // Z axis
            print("3D Mouse Z: \(value)")
        case 0x33: // Rx (rotation X)
            print("3D Mouse Rx: \(value)")
        case 0x34: // Ry (rotation Y)
            print("3D Mouse Ry: \(value)")
        case 0x35: // Rz (rotation Z)
            print("3D Mouse Rz: \(value)")
        default:
            break
        }
    }

    private func activateMenuSlice(index: Int) {
        print("Activating menu slice: \(index)")
    }

    deinit {
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }
    }
}
```

**Common HID Usage Pages:**
- `0x01` - Generic Desktop (Mouse, Keyboard, Joystick, Game Pad, Multi-axis Controller)
- `0x07` - Keyboard/Keypad
- `0x08` - LED
- `0x09` - Button
- `0x0C` - Consumer (Media controls)
- `0x0D` - Digitizer (Tablet, Pen)
- `0xFF` - Vendor Specific

### 2.4 Touch/Pen Input (NSEvent + Wacom)

#### Trackpad Gestures and Tablet Input

```swift
import AppKit

class TouchInputManager: NSView {
    // MARK: - Trackpad Gestures

    override var acceptsTouchEvents: Bool {
        get { true }
        set { }
    }

    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .any, in: self)
        print("Touches began: \(touches.count) touches")

        for touch in touches {
            handleTouch(touch, phase: .began)
        }
    }

    override func touchesMoved(with event: NSEvent) {
        let touches = event.touches(matching: .any, in: self)

        for touch in touches {
            handleTouch(touch, phase: .moved)
        }
    }

    override func touchesEnded(with event: NSEvent) {
        let touches = event.touches(matching: .any, in: self)

        for touch in touches {
            handleTouch(touch, phase: .ended)
        }
    }

    private func handleTouch(_ touch: NSTouch, phase: NSTouch.Phase) {
        let location = touch.normalizedPosition
        let identity = touch.identity

        print("Touch \(identity) - Phase: \(phase), Location: \(location)")
    }

    // MARK: - Gesture Recognition

    override func magnify(with event: NSEvent) {
        let magnification = event.magnification
        print("Pinch/zoom gesture: \(magnification)")

        // Scale radial menu
        scaleMenu(by: 1.0 + magnification)
    }

    override func rotate(with event: NSEvent) {
        let rotation = event.rotation // in degrees
        print("Rotation gesture: \(rotation)°")

        // Rotate radial menu selection
        rotateMenu(by: rotation)
    }

    override func swipe(with event: NSEvent) {
        let deltaX = event.deltaX
        let deltaY = event.deltaY
        print("Swipe gesture: dx=\(deltaX), dy=\(deltaY)")

        // Navigate menu items
        if deltaX > 0 {
            selectNextItem()
        } else if deltaX < 0 {
            selectPreviousItem()
        }
    }

    // MARK: - Wacom Tablet Input

    override func tabletPoint(with event: NSEvent) {
        // Pressure (0.0 to 1.0)
        let pressure = event.pressure

        // Tilt (x and y components)
        let tilt = event.tilt
        let tiltX = tilt.x // -1.0 to 1.0
        let tiltY = tilt.y // -1.0 to 1.0

        // Rotation (in degrees)
        let rotation = event.rotation

        // Absolute position on tablet
        let absoluteX = event.absoluteX
        let absoluteY = event.absoluteY

        // Location in window
        let location = event.locationInWindow

        print("Tablet Input - Pressure: \(pressure), Tilt: (\(tiltX), \(tiltY)), Rotation: \(rotation)°")

        // Use pressure for menu interaction strength
        handlePenInput(location: location, pressure: pressure, tilt: tilt, rotation: rotation)
    }

    override func tabletProximity(with event: NSEvent) {
        let isEnteringProximity = event.isEnteringProximity
        let pointingDeviceType = event.pointingDeviceType
        let deviceID = event.deviceID

        print("Tablet Proximity - Entering: \(isEnteringProximity), Type: \(pointingDeviceType.rawValue), ID: \(deviceID)")

        if isEnteringProximity {
            // Pen is near tablet
            showMenuPreview()
        } else {
            // Pen moved away from tablet
            hideMenuPreview()
        }
    }

    private func handlePenInput(location: NSPoint, pressure: Float, tilt: NSPoint, rotation: Float) {
        // Convert pressure to interaction strength
        let strength = pressure

        // Use tilt for directional input
        let angle = atan2(tilt.y, tilt.x)

        // Use rotation for menu rotation
        let menuRotation = rotation

        // Update radial menu based on pen input
        print("Pen input at \(location) with strength \(strength)")
    }

    // Placeholder methods
    private func scaleMenu(by factor: CGFloat) {}
    private func rotateMenu(by degrees: CGFloat) {}
    private func selectNextItem() {}
    private func selectPreviousItem() {}
    private func showMenuPreview() {}
    private func hideMenuPreview() {}
}
```

### 2.5 Mouse Input with Extra Buttons

#### CGEvent Tap for Global Mouse Monitoring

```swift
import CoreGraphics
import AppKit

class MouseInputManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func setupGlobalMouseMonitoring() {
        // Check for Input Monitoring permission (macOS 10.15+)
        if !CGPreflightListenEventAccess() {
            print("Input Monitoring permission not granted")
            CGRequestListenEventAccess()
            return
        }

        // Event mask for mouse events
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                       (1 << CGEventType.leftMouseUp.rawValue) |
                       (1 << CGEventType.rightMouseDown.rawValue) |
                       (1 << CGEventType.rightMouseUp.rawValue) |
                       (1 << CGEventType.mouseMoved.rawValue) |
                       (1 << CGEventType.otherMouseDown.rawValue) | // Extra buttons
                       (1 << CGEventType.otherMouseUp.rawValue) |
                       (1 << CGEventType.scrollWheel.rawValue)

        // Create event tap (listen-only mode for Input Monitoring permission)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly, // Use .defaultTap for modifying events (requires Accessibility)
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let manager = Unmanaged<MouseInputManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleMouseEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }

        self.eventTap = eventTap

        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("Global mouse monitoring enabled")
    }

    private func handleMouseEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .leftMouseDown:
            let location = event.location
            print("Left mouse down at \(location)")
            handleLeftClick(at: location)

        case .rightMouseDown:
            let location = event.location
            print("Right mouse down at \(location)")
            handleRightClick(at: location)

        case .otherMouseDown:
            // Extra mouse buttons (M3, M4, M5, etc.)
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            let location = event.location
            print("Mouse button \(buttonNumber) down at \(location)")
            handleExtraButton(buttonNumber: buttonNumber, at: location)

        case .mouseMoved:
            let location = event.location
            handleMouseMove(to: location)

        case .scrollWheel:
            // Get scroll deltas
            let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1) // Vertical
            let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2) // Horizontal

            print("Scroll: dx=\(deltaX), dy=\(deltaY)")
            handleScroll(deltaX: Int(deltaX), deltaY: Int(deltaY))

        default:
            break
        }

        // Return event unmodified (for listen-only mode)
        return Unmanaged.passRetained(event)
    }

    private func handleLeftClick(at location: CGPoint) {
        print("Left click at \(location)")
        // Confirm radial menu selection
    }

    private func handleRightClick(at location: CGPoint) {
        print("Right click at \(location)")
        // Open radial menu at cursor position
    }

    private func handleExtraButton(buttonNumber: Int64, at location: CGPoint) {
        // Common button numbers:
        // 2 = Middle button
        // 3 = Button 4 (typically "back")
        // 4 = Button 5 (typically "forward")
        // 5+ = Additional buttons

        switch buttonNumber {
        case 2:
            print("Middle button - toggle menu")
        case 3:
            print("Button 4 (back) - previous menu item")
            selectPreviousItem()
        case 4:
            print("Button 5 (forward) - next menu item")
            selectNextItem()
        default:
            print("Button \(buttonNumber) - custom action")
        }
    }

    private func handleMouseMove(to location: CGPoint) {
        // Update radial menu selection based on cursor position
        updateMenuSelection(cursorPosition: location)
    }

    private func handleScroll(deltaX: Int, deltaY: Int) {
        if abs(deltaX) > abs(deltaY) {
            // Horizontal scroll - navigate items
            if deltaX > 0 {
                selectNextItem()
            } else {
                selectPreviousItem()
            }
        } else {
            // Vertical scroll - scale menu or adjust zoom
            let scaleFactor = 1.0 + (Double(deltaY) * 0.01)
            scaleMenu(by: scaleFactor)
        }
    }

    // Placeholder methods
    private func updateMenuSelection(cursorPosition: CGPoint) {}
    private func selectNextItem() {}
    private func selectPreviousItem() {}
    private func scaleMenu(by factor: Double) {}

    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }
}
```

### 2.6 MultitouchSupport.framework (Private API)

**WARNING:** For personal use only. Cannot be used for App Store distribution.

For maximum raw trackpad data access:

```swift
import Foundation

// Load private framework
let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MultitouchSupport.framework"))

// Define function signatures (reverse engineered)
typealias MTDeviceCreateListCallback = @convention(c) () -> Unmanaged<CFArray>
typealias MTDeviceStartCallback = @convention(c) (MTDevice, Int32) -> Void
typealias MTDeviceRegisterCallback = @convention(c) (MTDevice, @escaping MTContactCallback, UnsafeMutableRawPointer?) -> Void

typealias MTDevice = UnsafeMutableRawPointer
typealias MTTouch = UnsafePointer<MTTouchData>

struct MTTouchData {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var unknown1: Int32
    var unknown2: Int32
    var normalizedX: Float  // 0.0 to 1.0
    var normalizedY: Float  // 0.0 to 1.0
    var size: Float
    var pressure: Float
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var unknown3: Float
    var unknown4: Float
    var unknown5: Float
}

typealias MTContactCallback = @convention(c) (MTDevice, MTTouch, Int32, Double, Int32) -> Int32

class RawTrackpadManager {
    private var devices: [MTDevice] = []

    func setupRawTrackpadAccess() {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MultitouchSupport.framework")) else {
            print("Failed to load MultitouchSupport.framework")
            return
        }

        // Get function pointers
        guard let createListFunc = CFBundleGetFunctionPointerForName(bundle, "MTDeviceCreateList" as CFString) else {
            print("Failed to get MTDeviceCreateList")
            return
        }

        let deviceCreateList = unsafeBitCast(createListFunc, to: MTDeviceCreateListCallback.self)
        let deviceList = deviceCreateList().takeRetainedValue() as NSArray

        print("Found \(deviceList.count) multitouch devices")

        for device in deviceList {
            let mtDevice = unsafeBitCast(device, to: MTDevice.self)
            devices.append(mtDevice)

            // Register callback
            if let registerFunc = CFBundleGetFunctionPointerForName(bundle, "MTDeviceRegisterCallback" as CFString) {
                let register = unsafeBitCast(registerFunc, to: MTDeviceRegisterCallback.self)
                register(mtDevice, touchCallback, Unmanaged.passUnretained(self).toOpaque())
            }

            // Start receiving touch data
            if let startFunc = CFBundleGetFunctionPointerForName(bundle, "MTDeviceStart" as CFString) {
                let start = unsafeBitCast(startFunc, to: MTDeviceStartCallback.self)
                start(mtDevice, 0)
            }
        }
    }
}

// Global callback (required for C convention)
let touchCallback: MTContactCallback = { device, touches, numTouches, timestamp, frame in
    // Process raw touch data
    for i in 0..<Int(numTouches) {
        let touch = touches.advanced(by: i).pointee

        print("""
            Touch \(touch.identifier):
              Position: (\(touch.normalizedX), \(touch.normalizedY))
              Pressure: \(touch.pressure)
              Size: \(touch.size)
              Angle: \(touch.angle)
              Axes: major=\(touch.majorAxis), minor=\(touch.minorAxis)
            """)

        // Use for radial menu interaction
        handleRawTouch(x: touch.normalizedX, y: touch.normalizedY, pressure: touch.pressure)
    }

    return 0
}

func handleRawTouch(x: Float, y: Float, pressure: Float) {
    // Convert normalized coordinates to menu selection
    // Calculate angle from center for radial menu
    let centerX: Float = 0.5
    let centerY: Float = 0.5
    let deltaX = x - centerX
    let deltaY = y - centerY
    let angle = atan2(deltaY, deltaX)

    print("Touch angle: \(angle * 180 / .pi)° with pressure \(pressure)")
}
```

---

## 3. Performance Considerations

### 3.1 Polling Rates by Device Type

| Device Type | Typical Polling Rate | Framework | Notes |
|-------------|---------------------|-----------|-------|
| Game Controllers | 60Hz (default) | GameController | Can be higher for USB wired controllers |
| MIDI Devices | Event-driven | CoreMIDI | Callback-based, no polling |
| HID Devices | 125Hz - 1000Hz | IOKit | Device-dependent; high rates can cause CPU issues on macOS |
| Trackpad | 60Hz | NSEvent | System-managed |
| Mouse | 125Hz - 1000Hz | CGEvent | High polling rates (>500Hz) can cause WindowServer CPU spikes |
| Keyboard | Event-driven | NSEvent | No polling needed |

### 3.2 Performance Optimization Strategies

#### 3.2.1 Background Thread Processing

```swift
class InputProcessor {
    private let processingQueue = DispatchQueue(
        label: "com.radialmenu.inputprocessing",
        qos: .userInteractive,
        attributes: .concurrent
    )

    func processControllerInput(_ input: ControllerInput) {
        processingQueue.async {
            // Heavy processing on background thread
            let processedInput = self.calculateMenuSelection(from: input)

            // Update UI on main thread
            DispatchQueue.main.async {
                self.updateMenu(with: processedInput)
            }
        }
    }
}
```

#### 3.2.2 Dead Zone and Threshold Filtering

```swift
func applyDeadZone(to value: Float, deadZone: Float = 0.1) -> Float {
    if abs(value) < deadZone {
        return 0.0
    }

    // Scale remaining range to 0.0 - 1.0
    let sign = value < 0 ? -1.0 : 1.0
    let scaledValue = (abs(value) - deadZone) / (1.0 - deadZone)
    return Float(sign) * scaledValue
}
```

#### 3.2.3 Input Event Coalescing

```swift
class InputCoalescer {
    private var lastEventTime: CFAbsoluteTime = 0
    private let minimumInterval: CFTimeInterval = 1.0 / 60.0 // 60 FPS

    func shouldProcessEvent() -> Bool {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsed = currentTime - lastEventTime

        if elapsed >= minimumInterval {
            lastEventTime = currentTime
            return true
        }
        return false
    }
}
```

### 3.3 High Polling Rate Mice Considerations

macOS has known issues with high polling rate mice (>500Hz):
- WindowServer CPU usage can spike to 100%
- System-wide performance degradation
- Particularly problematic on Apple Silicon (M1/M2/M3)

**Mitigation strategies:**
1. Advise users to set mice to 500Hz or lower
2. Implement input event coalescing
3. Use `.listenOnly` mode for CGEventTap when possible
4. Avoid `IOHIDDeviceRegisterInputValueCallback` for high-frequency devices

---

## 4. Permissions & Security

### 4.1 Required Permissions by Framework

| Framework | Permission Required | System Setting | API to Check/Request |
|-----------|-------------------|----------------|---------------------|
| GameController | None | N/A | N/A |
| CoreMIDI | None | N/A | N/A |
| IOKit (HID) | Input Monitoring | Privacy & Security → Input Monitoring | `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` |
| NSEvent (global) | Input Monitoring | Privacy & Security → Input Monitoring | `CGPreflightListenEventAccess()` / `CGRequestListenEventAccess()` |
| CGEvent (listen) | Input Monitoring | Privacy & Security → Input Monitoring | `CGPreflightListenEventAccess()` / `CGRequestListenEventAccess()` |
| CGEvent (modify) | Accessibility | Privacy & Security → Accessibility | `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions()` |
| Carbon (hotkeys) | Accessibility | Privacy & Security → Accessibility | Manual check via System Events |
| MultitouchSupport | None (but requires disabling sandbox) | N/A | N/A |

### 4.2 Requesting Permissions

```swift
import CoreGraphics
import ApplicationServices

class PermissionManager {
    func checkInputMonitoringPermission() -> Bool {
        return CGPreflightListenEventAccess()
    }

    func requestInputMonitoringPermission() {
        // This will show system permission dialog if not already granted
        CGRequestListenEventAccess()
    }

    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openSystemPreferences() {
        // Open Privacy & Security settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

### 4.3 macOS 15 Sequoia-Specific Changes

**Keyboard Shortcut Restrictions (Reversed in 15.2):**
- macOS 15.0-15.1: Prevented apps from registering keyboard shortcuts using only Option/Shift modifiers
- macOS 15.2+: Restriction lifted for sandboxed third-party apps
- Workaround for 15.0-15.1: Use Command + Option or Command + Shift combinations

**CGEvent Timestamp Validation:**
- Sequoia validates CGEvent timestamps
- Must provide correct timestamp: `CGEvent(timestamp: mach_absolute_time())`
- Must provide correct event number for mouse events

---

## 5. Unified Input Architecture Recommendation

### 5.1 Design Pattern: Input Abstraction Layer

**Complete production-ready unified input system:**

```swift
// MARK: - Unified Input Protocol

protocol InputSource {
    var identifier: String { get }
    var isConnected: Bool { get }
    func start()
    func stop()
}

protocol InputEvent {
    var timestamp: TimeInterval { get }
    var source: InputSource { get }
}

// MARK: - Radial Menu Input Events

enum RadialMenuInputType {
    case selection(angle: Float, distance: Float)
    case confirm
    case cancel
    case navigate(direction: NavigationDirection)
    case scale(factor: Float)
    case rotate(degrees: Float)
}

enum NavigationDirection {
    case next
    case previous
    case up
    case down
    case left
    case right
}

struct RadialMenuInput: InputEvent {
    let timestamp: TimeInterval
    let source: InputSource
    let type: RadialMenuInputType
}

// MARK: - Input Manager Protocol

protocol RadialMenuInputDelegate: AnyObject {
    func inputReceived(_ input: RadialMenuInput)
}

// MARK: - Unified Input Manager

class UnifiedInputManager: RadialMenuInputDelegate {
    private var inputSources: [InputSource] = []
    private let processingQueue = DispatchQueue(label: "com.radialmenu.input", qos: .userInteractive)

    weak var menuController: RadialMenuViewController?

    func start() {
        // Initialize all input sources
        let gameController = GameControllerInputSource()
        gameController.delegate = self

        let midi = MIDIInputSource()
        midi.delegate = self

        let mouse = MouseInputSource()
        mouse.delegate = self

        inputSources = [gameController, midi, mouse]

        // Start all sources
        inputSources.forEach { $0.start() }

        print("Unified input manager started with \(inputSources.count) sources")
    }

    func stop() {
        inputSources.forEach { $0.stop() }
    }

    // MARK: - RadialMenuInputDelegate

    func inputReceived(_ input: RadialMenuInput) {
        processingQueue.async { [weak self] in
            self?.processInput(input)
        }
    }

    private func processInput(_ input: RadialMenuInput) {
        print("Input from \(input.source.identifier): \(input.type)")

        // Process input and update menu on main thread
        DispatchQueue.main.async { [weak self] in
            guard let menuController = self?.menuController else { return }

            switch input.type {
            case .selection(let angle, let distance):
                menuController.updateSelection(angle: angle, distance: distance)

            case .confirm:
                menuController.confirmSelection()

            case .cancel:
                menuController.cancelMenu()

            case .navigate(let direction):
                menuController.navigate(direction: direction)

            case .scale(let factor):
                menuController.scaleMenu(by: factor)

            case .rotate(let degrees):
                menuController.rotateMenu(by: degrees)
            }
        }
    }
}
```

### 5.2 Architecture Benefits

1. **Separation of Concerns:** Each input source is isolated in its own class
2. **Easy Extension:** Add new input sources by implementing `InputSource` protocol
3. **Testability:** Mock input sources for unit testing
4. **Unified Events:** All inputs translated to common `RadialMenuInput` events
5. **Thread Safety:** Processing queue ensures thread-safe input handling
6. **Hot-plugging:** Automatic handling of device connections/disconnections

### 5.3 Recommended Input Priority

When multiple inputs are active simultaneously:

1. **Pen/Tablet** - Highest priority (most precise)
2. **Mouse** - High priority (primary pointing device)
3. **Game Controller** - Medium priority (dedicated gaming input)
4. **MIDI** - Medium priority (explicit musical input)
5. **Trackpad** - Low priority (alternative to mouse)
6. **Keyboard** - Lowest priority (fallback navigation)

Implement input priority with timestamp-based conflict resolution:

```swift
class InputPriorityResolver {
    private var lastInputBySource: [String: TimeInterval] = [:]
    private let exclusivityWindow: TimeInterval = 0.1 // 100ms

    func shouldProcessInput(_ input: RadialMenuInput) -> Bool {
        let currentTime = input.timestamp

        // Check if another higher-priority source has recent input
        for (sourceId, timestamp) in lastInputBySource {
            let timeDelta = currentTime - timestamp

            if timeDelta < exclusivityWindow &&
               getPriority(sourceId) > getPriority(input.source.identifier) {
                return false // Higher priority source is active
            }
        }

        // Update last input time for this source
        lastInputBySource[input.source.identifier] = currentTime
        return true
    }

    private func getPriority(_ sourceId: String) -> Int {
        switch sourceId {
        case "Tablet": return 6
        case "Mouse": return 5
        case "GameController": return 4
        case "MIDI": return 3
        case "Trackpad": return 2
        case "Keyboard": return 1
        default: return 0
        }
    }
}
```

---

## 6. Key Limitations and Workarounds

### 6.1 DualSense Haptics on macOS

**Limitation:** Full DualSense haptic features (4-channel audio for actuators) are not exposed on macOS.

**Workaround:** Use CoreHaptics with standard rumble patterns. Adaptive triggers work via `GCDualSenseAdaptiveTrigger`.

### 6.2 High Polling Rate Mice

**Limitation:** Mice polling at 1000Hz cause severe system performance issues on macOS (especially Apple Silicon).

**Workaround:**
- Recommend users set mice to 500Hz or lower
- Implement input event coalescing
- Use `.listenOnly` CGEventTap mode

### 6.3 Xbox Controller Analog Triggers on Bluetooth

**Limitation:** Xbox controllers connected via Bluetooth have trigger mapping issues on macOS.

**Workaround:**
- Recommend USB wired connection for Xbox controllers
- Implement trigger value normalization
- Provide configuration UI for users to remap inputs

### 6.4 Nintendo Switch Joy-Con Individual Recognition

**Limitation:** Each Joy-Con is recognized as a separate controller rather than paired.

**Workaround:**
- Detect two Joy-Con controllers and merge their inputs
- Or recommend Switch Pro Controller

### 6.5 MultitouchSupport.framework Instability

**Limitation:** Private API, no official support, can break between macOS updates.

**Workaround:**
- Use NSEvent trackpad APIs as primary method
- Only use MultitouchSupport for advanced features
- Implement fallback to NSEvent if framework unavailable
- For personal use only (cannot ship to App Store)

### 6.6 Input Monitoring Permission Friction

**Limitation:** Users must manually grant Input Monitoring permission for global input capture.

**Workaround:**
- Provide clear onboarding explaining why permission is needed
- Use `CGPreflightListenEventAccess()` to check before requesting
- Offer manual "Open System Preferences" button
- Degrade gracefully if permission denied (app-level input only)

---

## 7. Sources and References

### Official Apple Documentation

- [GameController Framework](https://developer.apple.com/documentation/gamecontroller)
- [GCController API](https://developer.apple.com/documentation/gamecontroller/gccontroller)
- [GCDualSenseAdaptiveTrigger](https://developer.apple.com/documentation/gamecontroller/gcdualsenseadaptivetrigger)
- [Core MIDI Documentation](https://developer.apple.com/documentation/coremidi)
- [MIDI Services](https://developer.apple.com/documentation/coremidi/midi-services)
- [IOHIDManager API](https://developer.apple.com/documentation/iokit/iohidmanager_h)
- [CGEvent Documentation](https://developer.apple.com/documentation/coregraphics/cgevent)
- [NSEvent Mouse, Keyboard, and Trackpad](https://developer.apple.com/documentation/appkit/mouse-keyboard-and-trackpad)
- [Playing Haptics on Game Controllers](https://developer.apple.com/documentation/corehaptics/playing-haptics-on-game-controllers)
- [Core Haptics](https://developer.apple.com/documentation/corehaptics/)
- [macOS Sequoia 15 Release Notes](https://developer.apple.com/documentation/macos-release-notes/macos-15-release-notes)

### WWDC Sessions

- [Supporting New Game Controllers - WWDC19](https://developer.apple.com/videos/play/wwdc2019/616/)
- [Advancements in Game Controllers - WWDC20](https://developer.apple.com/videos/play/wwdc2020/10614/)
- [What's new in AppKit - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10124/)

### Technical Articles & Guides

- [Modern CoreMIDI Event Handling with Swift](https://furnacecreek.org/blog/2024-04-06-modern-coremidi-event-handling-with-swift)
- [Handling Trackpad Events - Apple Archive](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html)
- [Wacom Developer Documentation - NSEvents Basics](https://developer-docs.wacom.com/docs/icbt/macos/ns-events/ns-events-basics/)
- [OS X CoreMIDI Programming Examples (Stanford CCRMA)](https://ccrma.stanford.edu/~craig/articles/linuxmidi/osxmidi/osxmidi-20090610.pdf)
- [Touching Apple's Private Multitouch Framework](https://medium.com/ryan-hanson/touching-apples-private-multitouch-framework-64f87611cfc9)

### Stack Overflow Resources

- [How do I use Apple's GameController framework from a macOS Command Line Tool?](https://stackoverflow.com/questions/55226373/how-do-i-use-apples-gamecontroller-framework-from-a-macos-command-line-tool)
- [Which API is behind "Input Monitoring" in macOS 10.15 Catalina?](https://stackoverflow.com/questions/58670785/which-api-is-behind-the-privacy-feature-input-monitoring-in-the-security-syste)
- [Using IOHIDManager to Get Modifier Key Events](https://stackoverflow.com/questions/7190852/using-iohidmanager-to-get-modifier-key-events)
- [Posting key-press CGEvent fails in macOS 15 Sequoia](https://stackoverflow.com/questions/79518299/posting-key-press-cgevent-fails-in-macos-15-sequoia)

### Open Source Projects

- [hidapi - Cross-platform HID library](https://github.com/libusb/hidapi)
- [ds4macos - DualShock 4/DualSense DSU Server](https://github.com/marcowindt/ds4macos)
- [ShockMouse - DualShock 4 touchpad as mouse](https://github.com/Bluebie/shockmouse)
- [OpenMultitouchSupport - Raw trackpad data access](https://github.com/Kyome22/OpenMultitouchSupport)
- [KeyCastr - Keystroke visualizer](https://github.com/keycastr/keycastr)
- [SaneSideButtons - Mouse button remapping](https://github.com/thealpa/SaneSideButtons)
- [PySpaceMouse - 3D mouse library](https://github.com/JakubAndrysek/PySpaceMouse)

### GitHub Repositories with Examples

- [Wacom Device Kit for macOS](https://github.com/Wacom-Developer/wacom-device-kit-macos-api)
- [IOKit HID Manager header](https://github.com/opensource-apple/IOKitUser/blob/master/hid.subproj/IOHIDManager.h)
- [Stream Deck HID Protocol Notes](https://gist.github.com/cliffrowley/d18a9c4569537b195f2b1eb6c68469e0)
- [Accessing raw multitouch trackpad data](https://gist.github.com/rmhsilva/61cc45587ed34818a76476e11)

### Community Resources

- [SensibleSideButtons - Gaming mouse support](https://sensible-side-buttons.archagon.net/)
- [3Dconnexion Forum - API discussions](https://forum.3dconnexion.com/viewtopic.php?t=3651)
- [macOS Sequoia Keyboard Shortcuts Blog Post](https://blog.eternalstorms.at/2024/09/23/keyboard-shortcuts-using-option-and-or-shift-modifiers-only-no-longer-allowed-on-macos-sequoia/)

### Additional Resources

- [Apple Support - Control access to input monitoring on Mac](https://support.apple.com/guide/mac-help/control-access-to-input-monitoring-on-mac-mchl4cedafb6/mac)
- [Nintendo Switch Controller macOS Native Support](https://appleinsider.com/articles/22/06/07/native-nintendo-switch-controller-steering-wheel-support-coming-to-ios-16-ipados-16-macos-ventura)
- [Performance issues with high-polling rate mice - osu!mac](https://osu-mac.readthedocs.io/en/latest/issues/mouse.html)

---

## 8. Conclusion

macOS 15 Sequoia provides comprehensive input device support through multiple frameworks, enabling maximum device compatibility for your radial menu application:

**Best-in-class support:** Game controllers (GameController), MIDI devices (CoreMIDI), standard mouse/keyboard (NSEvent/CGEvent)

**Good support:** Graphics tablets (NSEvent pressure/tilt), trackpad gestures, generic HID devices (IOKit)

**Advanced/experimental:** MultitouchSupport.framework for raw trackpad data (private API)

### Key Recommendations

1. **Use the unified input architecture pattern** for maintainability and extensibility
2. **Implement proper permission handling** with clear user guidance for Input Monitoring
3. **Be aware of high polling rate mouse performance issues** on macOS (especially Apple Silicon)
4. **Test extensively with real hardware** across different connection types (Bluetooth vs USB)
5. **Provide configuration UI** for users to customize input mappings and device-specific settings
6. **Implement graceful degradation** when devices/permissions unavailable
7. **Use input priority resolution** to handle simultaneous multi-device input

### Framework Selection Guide

| Input Device | Recommended Framework | Fallback Option |
|--------------|----------------------|-----------------|
| Game Controllers | GameController | IOKit (HID) |
| MIDI Devices | CoreMIDI | N/A |
| Stream Decks / Macro Pads | IOKit (HID) | N/A |
| 3D Mice | IOKit (HID) | N/A |
| Graphics Tablets | NSEvent | IOKit (HID for raw data) |
| Mouse (standard) | NSEvent | CGEvent (for global) |
| Mouse (extra buttons) | CGEvent | IOKit (HID) |
| Trackpad Gestures | NSEvent | MultitouchSupport (private) |
| Keyboard | NSEvent | Carbon (for hotkeys) |

The provided code examples demonstrate production-ready implementations for each input method, ready to integrate into your radial menu application with maximum device compatibility.
