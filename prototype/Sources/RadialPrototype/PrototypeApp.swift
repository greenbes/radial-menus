import AppKit
import Observation
import SwiftUI
import GameController
import RadialCore
import RadialRuntime
import RadialMac
import RadialUI

@main @MainActor enum PrototypeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = ApplicationDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@Observable @MainActor final class EventLog {
    private(set) var lines: [String] = []
    private var file: FileHandle?

    init(url: URL?) throws {
        if let url {
            try Data().write(to: url, options: .atomic)
            file = try FileHandle(forWritingTo: url)
            write(["kind": "environment", "format": 1,
                   "os": ProcessInfo.processInfo.operatingSystemVersionString])
        }
    }

    func append(_ message: String) {
        lines.append(message)
        if lines.count > 150 { lines.removeFirst(lines.count - 150) }
        write(["kind": "message", "uptime": ProcessInfo.processInfo.systemUptime, "message": message])
    }

    func record(_ event: Event, _ transition: RadialCore.Transition) {
        guard file != nil else { return }
        write(TransitionRecording.value(event: event, transition: transition))
    }

    func recordResources(_ values: [String: Any]) {
        var record = values
        record["kind"] = "shutdownResources"
        record["uptime"] = ProcessInfo.processInfo.systemUptime
        write(record)
    }

    func recordProbe(_ values: [String: Any]) {
        var record = values
        record["kind"] = "shutdownProbe"
        record["uptime"] = ProcessInfo.processInfo.systemUptime
        write(record)
    }

    private func write(_ record: [String: Any]) {
        if let file {
            do {
                let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
                try file.write(contentsOf: data + Data([10]))
            }
            catch { self.file = nil; lines.append("Recording failed: \(error.localizedDescription)") }
        }
    }
}

@MainActor final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private var store: Store!
    private let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer())
    private let controllers = ControllerAdapter()
    private let scheduler = TaskScheduler()
    private var log: EventLog!
    private var status: NSStatusItem?
    private var diagnostics: NSWindow?
    private var terminationRequested = false
    private var terminationReplyScheduled = false
    private var terminationSignal: DispatchSourceSignal?
    private var shutdownProbe: ShutdownProbe?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let path = argument("--layout-test") {
            Task { @MainActor in
                let passed = await NativeLayoutProbe.run(directory: URL(fileURLWithPath: path),
                    style: requestedStyle ?? .pie)
                exit(passed ? 0 : 1)
            }
            return
        }
        do {
            log = try EventLog(url: argument("--record").map { URL(fileURLWithPath: $0) })
        } catch {
            FileHandle.standardError.write(Data("Cannot create event recording: \(error)\n".utf8))
            exit(1)
        }
        if let stage = argument("--shutdown-test") {
            guard let stage = ShutdownProbe.Stage(rawValue: stage) else {
                FileHandle.standardError.write(Data("Unknown shutdown test stage\n".utf8))
                exit(2)
            }
            shutdownProbe = ShutdownProbe(stage: stage, panel: panel)
        }
        let window: any WindowDriver = shutdownProbe ?? panel
        let usesColors = argument("--smoke-test") != nil || shutdownProbe != nil || CommandLine.arguments.contains("--color-demo")
        store = Store(menu: usesColors ? SampleMenu.definition : DemoMenu.definition,
                      menuStyle: requestedStyle ?? (usesColors ? .pie : .selectedMessage), window: window, controller: controllers,
                      scheduler: scheduler, movementClock: scheduler)
        panel.content = NSHostingView(rootView: MenuContainer(store: store))
        panel.onNativeObservation = { [weak log] in log?.append("Window: " + $0) }
        controllers.receive = { [weak store, weak log] event in
            log?.append("Controller: \(event)")
            store?.send(event)
        }
        store.onOutput = { [weak self] output in
            self?.log.append("Result: \(output)")
            if case .shutdownCompleted = output, self?.terminationRequested == true {
                self?.scheduleTerminationReply()
            }
        }
        store.onTransition = { [weak log] event, transition in log?.record(event, transition) }
        installMenu()
        signal(SIGTERM, SIG_IGN)
        let terminationSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        terminationSignal.setEventHandler { [weak self] in self?.quitApp() }
        terminationSignal.resume()
        self.terminationSignal = terminationSignal
        store.send(.start)
        if let shutdownProbe {
            Task { @MainActor in await shutdownProbe.run(store: store, log: log, quit: quitApp) }
        } else if let path = argument("--smoke-test") {
            Task { @MainActor in
                let probe = NativeSmoke(store: store, panel: panel)
                let passed = await probe.run(report: URL(fileURLWithPath: path))
                store.send(.stop)
                exit(passed ? 0 : 1)
            }
        } else {
            showDiagnostics()
        }
    }

    private var requestedStyle: RadialCore.MenuStyle? {
        if CommandLine.arguments.contains("--floating-labels") { return .floatingLabels }
        if CommandLine.arguments.contains("--icon-labels") { return .iconLabels }
        if CommandLine.arguments.contains("--cards") { return .cards }
        if CommandLine.arguments.contains("--full-labels") { return .fullLabels }
        if CommandLine.arguments.contains("--selected-message") { return .selectedMessage }
        return nil
    }

    private func argument(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    private func installMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let quit = NSMenuItem(title: "Quit Radial Prototype", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        appMenu.addItem(quit)
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu

        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "circle.grid.2x2", accessibilityDescription: "Radial Prototype")
        let menu = NSMenu()
        for (title, action) in [("Open menu", #selector(openMenu)), ("Show diagnostics", #selector(showDiagnostics)),
                                ("Recover window", #selector(recover)), ("Quit", #selector(quitApp))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        status.menu = menu
        self.status = status
    }

    @objc private func openMenu() { store.send(.open(nil)) }
    @objc private func recover() { store.send(.recover) }
    @objc private func quitApp() {
        // terminateLater runs a nested AppKit loop. Enter it from the run loop,
        // after the current Swift task or dispatch callback has returned, so
        // that cleanup tasks and the final reply can still use the main queue.
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
    }

    @objc private func showDiagnostics() {
        if diagnostics == nil {
            let window = makeDiagnosticsWindow(store: store, log: log)
            diagnostics = window
        }
        NSApp.activate(ignoringOtherApps: true)
        diagnostics?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        if !terminationRequested {
            terminationRequested = true
            log.append("Application termination requested")
            store.send(.stop)
        }
        if case .stopped = store.model.lifecycle { scheduleTerminationReply() }
        return .terminateLater
    }

    private func scheduleTerminationReply() {
        guard !terminationReplyScheduled else { return }
        terminationReplyScheduled = true
        // A synchronous native acknowledgment can reach this callback while
        // applicationShouldTerminate is still on the stack. Reply on the next
        // main-queue turn, after AppKit has received terminateLater.
        DispatchQueue.main.async { [self] in
            terminationSignal?.cancel()
            terminationSignal = nil
            if let status { NSStatusBar.system.removeStatusItem(status) }
            status = nil
            diagnostics?.close()
            diagnostics = nil
            log.recordResources([
                "panelVisible": panel.isVisible,
                "panelResources": panel.hasNativeResources,
                "controllerResources": controllers.hasNativeResources,
                "deadlineCount": scheduler.activeDeadlineCount,
                "movementCount": scheduler.activeMovementCount,
                "backgroundMonitoringRestored": controllers.backgroundMonitoringRestored,
                "inputHandlersReleased": GCController.controllers().allSatisfy { $0.input.inputStateAvailableHandler == nil }
            ])
            NSApp.reply(toApplicationShouldTerminate: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        log?.append("Application will terminate")
    }
}

@MainActor struct MenuContainer: View {
    let store: Store
    var body: some View { MenuView(model: store.view) { store.send($0) } }
}

@MainActor func makeDiagnosticsWindow(store: Store, log: EventLog) -> NSWindow {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 760),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Radial Menu Prototype"
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: DiagnosticsView(store: store, log: log).background(Color(nsColor: .windowBackgroundColor)))
    window.center()
    return window
}

@MainActor private struct DiagnosticsView: View {
    let store: Store
    let log: EventLog

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Radial Menu Prototype").font(.title2.bold())
            Text("Explore a menu using a controller, keyboard, or the menu buttons. Choices appear here; they do not execute commands.")
            Picker("Menu style", selection: Binding(get: { store.model.menuStyle }, set: { store.send(.setMenuStyle($0)) })) {
                ForEach(RadialCore.MenuStyle.allCases, id: \.self) { style in Text(style.title).tag(style) }
            }
            .pickerStyle(.menu)
            .disabled(!store.model.running)
            Text("Style changes apply the next time you open the menu.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Open menu") { store.send(.open(nil)) }
                    .disabled(!store.model.canOpen)
                Button("Recover window") { store.send(.recover) }
                    .disabled(!store.model.canRecover)
                Spacer()
                Text(store.model.phase.name).font(.headline)
            }
            GroupBox("Controllers") {
                VStack(alignment: .leading, spacing: 8) {
                    if store.model.controllers.isEmpty { Text("No controller detected by macOS.") }
                    ForEach(store.model.controllers.keys.sorted(), id: \.self) { id in
                        if let controller = store.model.controllers[id] {
                            Text(controller.info.name).bold()
                            Text(controller.info.supported ? controller.info.detail : "Unsupported: \(controller.info.detail)")
                                .font(.caption)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Text("Controller: Menu opens or cancels. Left stick selects; right stick moves the menu. D-pad left/right steps. Confirm chooses; Back returns or cancels. Center both sticks when entering a submenu.")
            Text("Mouse movement selects; clicking chooses that item. Keyboard: arrows select, Return chooses, Delete goes back, Escape cancels the whole interaction. A stationary mouse or stick does not override another input's selection.")
            GroupBox("Recent results") {
                VStack(alignment: .leading, spacing: 5) {
                    if store.outputs.isEmpty { Text("No completed interaction yet.").foregroundStyle(.secondary) }
                    ForEach(Array(store.outputs.suffix(4).enumerated()), id: \.offset) { _, output in
                        Text(description(output)).textSelection(.enabled)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Observed events") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(log.lines.suffix(35).enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minHeight: 100)
            }
        }.padding(24).frame(minWidth: 570, minHeight: 700)
    }

    private func description(_ output: Output) -> String {
        switch output {
        case .rejected(let reason): "Could not open: \(reason.rawValue)"
        case .completed(_, .selected(let choice)): "Selected \(choice.value)"
        case .completed(_, .cancelled(let reason)): "Cancelled: \(reason.rawValue)"
        case .completed(_, .failed(let failure)): "Failed: \(failure.message)"
        case .shutdownCompleted(.completed): "Application resources released"
        case .shutdownCompleted(.failed(let message)): "Shutdown failed: \(message)"
        }
    }
}
