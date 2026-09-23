# Lifecycle checks

These checks define the expected behavior before observing native results.
Use the fixed example menu and record the complete event stream. A controller
value fixture establishes core behavior; physical Bluetooth testing establishes
whether macOS delivers the required connection events on the tested device.

## Controller loss and reconnection

1. Open using a controller and begin selection or movement.
2. Disconnect that controller. Its connection identity is removed, movement
   stops, and dismissal begins. No selected value is committed by disconnection.
3. After native dismissal, emit exactly one `controllerLost` cancellation.
4. Reconnect the same physical controller with a new connection identity.
   Its initial button and stick observations establish a baseline, not presses.
5. Reject events, ticks, and window operations from the old interaction.
6. Release held controls and use fresh presses to open and complete a new
   interaction. Confirm must also be released after any baseline that observed
   it held. The new interaction returns its own choice exactly once.

Losing another controller cannot cancel the owner's interaction. Loss after
a choice has already been committed cannot replace that choice with a
cancellation. Cleanup failure must still be reported as failure.

For the GuliKit Controller XW over Bluetooth, power the controller off using
its hardware controls while the menu remains active. Do not switch to Bluetooth
settings first: changing application focus would test focus-loss cancellation.
Power it back on and wait for reconnection. The bottom button labeled B confirms;
the right button labeled A goes back. Record connection identities and actual
results, including delays or missing disconnection notifications.

## Shutdown

Request shutdown while idle, opening, active, moving, dismissing a committed
choice, and recovering from failure. The expected trace is:

1. Commit the stopping state. Reject new opens and disable interaction.
2. Stop controller monitoring and movement scheduling. Cancel an uncommitted
   interaction with `applicationStopping`; preserve a committed choice.
3. Finish the session's native cleanup and emit its one terminal result.
4. Release the panel, pointer monitoring, and window observers. Acknowledge
   their release explicitly, then remove the remaining deadline.
5. Emit one shutdown result and permit application termination.

Use a four-second overall shutdown deadline, independent of the three-second
native operation deadline. Repeated requests do not extend it. If the deadline
expires, report any unresolved session as failed, preserve its committed choice
in that failure, attempt final resource release, and emit a failed shutdown
result. A late acknowledgment cannot turn failure into success. These are
cooperative deadlines; a blocked main thread cannot process a timer callback.

Controlled tests explicitly fire missing-completion deadlines. Native process
checks must observe the termination request, result ordering, resource state,
and actual process exit. An exit code alone does not establish cleanup.
