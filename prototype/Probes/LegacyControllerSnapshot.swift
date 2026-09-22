// Run with: swift prototype/Probes/LegacyControllerSnapshot.swift
// This probe checks whether Apple's legacy writable snapshot can supply a
// fixture for its newer buffered input API. It is not an input adapter test.
import Foundation
import GameController

let controller = GCController.withExtendedGamepad()
controller.extendedGamepad?.buttonA.setValue(1)
controller.extendedGamepad?.leftThumbstick.setValueForXAxis(0.5, yAxis: -0.75)
let until = Date().addingTimeInterval(1)
while Date() < until { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
let captured = controller.input.capture()
print("Legacy A pressed:", controller.extendedGamepad?.buttonA.isPressed as Any)
print("Buffered A pressed:", captured.buttons[GCInputButtonA]?.pressedInput.isPressed as Any)
print("Legacy stick x:", controller.extendedGamepad?.leftThumbstick.xAxis.value as Any)
print("Buffered stick x:", captured.dpads[GCInputLeftThumbstick]?.xAxis.value as Any)
