//
//  PreferencesView.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Preferences window view
struct PreferencesView: View {
    let configuration: MenuConfiguration
    let iconSetProvider: IconSetProviderProtocol
    let onResetToDefault: () -> Void
    let onUpdateIconSetIdentifier: (String) -> Void
    let onUpdateBackgroundColor: (CodableColor) -> Void
    let onUpdateForegroundColor: (CodableColor) -> Void
    let onUpdateSelectedItemColor: (CodableColor) -> Void
    let onUpdatePositionMode: (BehaviorSettings.PositionMode) -> Void
    let onAddItem: (MenuItem) -> Void
    let onRemoveItem: (UUID) -> Void
    let onUpdateRadius: (Double) -> Void
    let onUpdateCenterRadius: (Double) -> Void
    let onUpdateJoystickDeadzone: (Double) -> Void

    @State private var selectedIconSetIdentifier: String
    @State private var backgroundColor: Color
    @State private var foregroundColor: Color
    @State private var selectedItemColor: Color
    @State private var positionMode: BehaviorSettings.PositionMode
    @State private var showingAddItemSheet = false
    @State private var showingImportSheet = false
    @State private var radius: Double
    @State private var radiusText: String
    @State private var centerRadius: Double
    @State private var centerRadiusText: String
    @State private var joystickDeadzone: Double
    @State private var items: [MenuItem]

    init(
        configuration: MenuConfiguration,
        iconSetProvider: IconSetProviderProtocol,
        onResetToDefault: @escaping () -> Void,
        onUpdateIconSetIdentifier: @escaping (String) -> Void,
        onUpdateBackgroundColor: @escaping (CodableColor) -> Void,
        onUpdateForegroundColor: @escaping (CodableColor) -> Void,
        onUpdateSelectedItemColor: @escaping (CodableColor) -> Void,
        onUpdatePositionMode: @escaping (BehaviorSettings.PositionMode) -> Void,
        onAddItem: @escaping (MenuItem) -> Void,
        onRemoveItem: @escaping (UUID) -> Void,
        onUpdateRadius: @escaping (Double) -> Void,
        onUpdateCenterRadius: @escaping (Double) -> Void,
        onUpdateJoystickDeadzone: @escaping (Double) -> Void
    ) {
        self.configuration = configuration
        self.iconSetProvider = iconSetProvider
        self.onResetToDefault = onResetToDefault
        self.onUpdateIconSetIdentifier = onUpdateIconSetIdentifier
        self.onUpdateBackgroundColor = onUpdateBackgroundColor
        self.onUpdateForegroundColor = onUpdateForegroundColor
        self.onUpdateSelectedItemColor = onUpdateSelectedItemColor
        self.onUpdatePositionMode = onUpdatePositionMode
        self.onAddItem = onAddItem
        self.onRemoveItem = onRemoveItem
        self.onUpdateRadius = onUpdateRadius
        self.onUpdateCenterRadius = onUpdateCenterRadius
        self.onUpdateJoystickDeadzone = onUpdateJoystickDeadzone
        _selectedIconSetIdentifier = State(initialValue: configuration.appearanceSettings.iconSetIdentifier)
        _backgroundColor = State(initialValue: configuration.appearanceSettings.backgroundColor.color)
        _foregroundColor = State(initialValue: configuration.appearanceSettings.foregroundColor.color)
        _selectedItemColor = State(initialValue: configuration.appearanceSettings.selectedItemColor.color)
        _positionMode = State(initialValue: configuration.behaviorSettings.positionMode)
        _radius = State(initialValue: configuration.appearanceSettings.radius)
        _radiusText = State(initialValue: String(Int(configuration.appearanceSettings.radius)))
        _centerRadius = State(initialValue: configuration.appearanceSettings.centerRadius)
        _centerRadiusText = State(initialValue: String(Int(configuration.appearanceSettings.centerRadius)))
        _joystickDeadzone = State(initialValue: configuration.behaviorSettings.joystickDeadzone)
        _items = State(initialValue: configuration.items)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Radial Menu Preferences")
                    .font(.title2)
                    .fontWeight(.bold)

                Divider()

                // Menu Items Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Menu Items")
                            .font(.headline)

                        Spacer()

                        Button(action: { showingAddItemSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add")
                        }
                    }

                    List(items) { item in
                        HStack {
                            iconImage(for: item)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.body)

                                Text(item.action.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                items.removeAll { $0.id == item.id }
                                onRemoveItem(item.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 200)
                }
                .sheet(isPresented: $showingAddItemSheet) {
                    AddMenuItemView(onAdd: { newItem in
                        items.append(newItem)
                        onAddItem(newItem)
                        showingAddItemSheet = false
                    }, onCancel: {
                        showingAddItemSheet = false
                    })
                }

                // Appearance Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.headline)

                    HStack {
                        Text("Icon Set:")
                        Picker("Icon Set", selection: $selectedIconSetIdentifier) {
                            ForEach(iconSetProvider.availableIconSets, id: \.identifier) { descriptor in
                                Text(descriptor.name).tag(descriptor.identifier)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedIconSetIdentifier) { _, newValue in
                            onUpdateIconSetIdentifier(newValue)
                        }

                        Button(action: { showingImportSheet = true }) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Import custom icon set")
                    }
                    .sheet(isPresented: $showingImportSheet) {
                        IconSetImportView(
                            iconSetProvider: iconSetProvider,
                            onDismiss: { showingImportSheet = false }
                        )
                    }

                    HStack {
                        Text("Background Color:")
                        ColorPicker("", selection: $backgroundColor, supportsOpacity: true)
                            .labelsHidden()
                            .onChange(of: backgroundColor) { _, newValue in
                                onUpdateBackgroundColor(CodableColor(color: newValue))
                            }
                    }

                    HStack {
                        Text("Foreground Color:")
                        ColorPicker("", selection: $foregroundColor, supportsOpacity: true)
                            .labelsHidden()
                            .onChange(of: foregroundColor) { _, newValue in
                                onUpdateForegroundColor(CodableColor(color: newValue))
                            }
                    }

                    HStack {
                        Text("Selected Item Color:")
                        ColorPicker("", selection: $selectedItemColor, supportsOpacity: true)
                            .labelsHidden()
                            .onChange(of: selectedItemColor) { _, newValue in
                                onUpdateSelectedItemColor(CodableColor(color: newValue))
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Radius:")
                            TextField("", text: $radiusText)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if let value = Double(radiusText) {
                                        let clampedValue = min(max(value, 50), 300)
                                        radius = clampedValue
                                        radiusText = String(Int(clampedValue))
                                        onUpdateRadius(clampedValue)
                                    } else {
                                        radiusText = String(Int(radius))
                                    }
                                }
                            Text("px")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $radius, in: 50...300, step: 1)
                            .onChange(of: radius) { _, newValue in
                                radiusText = String(Int(newValue))
                                onUpdateRadius(newValue)
                            }

                        Text("Range: 50-300 pixels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Center Radius:")
                            TextField("", text: $centerRadiusText)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if let value = Double(centerRadiusText) {
                                        let clampedValue = min(max(value, 20), 250)
                                        centerRadius = clampedValue
                                        centerRadiusText = String(Int(clampedValue))
                                        onUpdateCenterRadius(clampedValue)
                                    } else {
                                        centerRadiusText = String(Int(centerRadius))
                                    }
                                }
                            Text("px")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $centerRadius, in: 20...250, step: 1)
                            .onChange(of: centerRadius) { _, newValue in
                                centerRadiusText = String(Int(newValue))
                                onUpdateCenterRadius(newValue)
                            }

                        Text("Range: 20-250 pixels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Behavior Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behavior")
                        .font(.headline)

                    HStack {
                        Text("Location at Launch:")
                        Picker("Location at Launch", selection: $positionMode) {
                            Text("Cursor").tag(BehaviorSettings.PositionMode.atCursor)
                            Text("Center").tag(BehaviorSettings.PositionMode.center)
                        }
                        .labelsHidden()
                        .onChange(of: positionMode) { _, newValue in
                            onUpdatePositionMode(newValue)
                        }
                    }

                    HStack {
                        Text("Show on All Spaces:")
                        Text(configuration.behaviorSettings.showOnAllSpaces ? "Yes" : "No")
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Joystick Deadzone:")
                            Text(String(format: "%.0f%%", joystickDeadzone * 100))
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $joystickDeadzone, in: 0.1...0.5, step: 0.05)
                            .onChange(of: joystickDeadzone) { _, newValue in
                                onUpdateJoystickDeadzone(newValue)
                            }

                        Text("Higher values ignore more stick drift (10-50%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Action Buttons
                HStack {
                    Button("Reset to Default") {
                        onResetToDefault()
                    }

                    Spacer()

                    Button("Close") {
                        NSApplication.shared.keyWindow?.close()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.bottom, 20)
            }
            .padding(20)
        }
        .frame(width: 500, height: 600)
    }

    private func iconImage(for item: MenuItem) -> Image {
        // For launchApp actions, show the application's actual icon
        if case .launchApp(let path) = item.action {
            let appIcon = NSWorkspace.shared.icon(forFile: path)
            return Image(nsImage: appIcon)
        }

        // Fall back to icon set resolution for other action types
        let resolved = iconSetProvider.resolveIcon(
            iconName: item.iconName,
            iconSetIdentifier: selectedIconSetIdentifier
        )
        if resolved.isSystemSymbol {
            return Image(systemName: resolved.name)
        } else if let fileURL = resolved.fileURL {
            if let nsImage = NSImage(contentsOf: fileURL) {
                return Image(nsImage: nsImage)
            }
            return Image(systemName: "questionmark.circle")
        } else if resolved.isAssetCatalog {
            return Image(resolved.name)
        } else {
            return Image(systemName: resolved.name)
        }
    }
}

// MARK: - Add Menu Item View

struct AddMenuItemView: View {
    let onAdd: (MenuItem) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var iconName: String = "app.fill"
    @State private var actionType: ActionTypeSelection = .launchApp
    @State private var appPath: String = ""
    @State private var shellCommand: String = ""
    @State private var selectedAppIcon: NSImage?
    @State private var selectedInternalCommand: InternalCommand = .switchApp

    enum ActionTypeSelection: String, CaseIterable {
        case launchApp = "Launch Application"
        case runShellCommand = "Run Shell Command"
        case internalCommand = "Internal Command"

        var systemImage: String {
            switch self {
            case .launchApp: return "app"
            case .runShellCommand: return "terminal"
            case .internalCommand: return "gear"
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Menu Item")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Title", text: $title)

                TextField("Icon Name (SF Symbol)", text: $iconName)

                Picker("Action Type", selection: $actionType) {
                    ForEach(ActionTypeSelection.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.systemImage)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }

                switch actionType {
                case .launchApp:
                    HStack {
                        if let icon = selectedAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.secondary)
                        }

                        Text(appPath.isEmpty ? "No application selected" : URL(fileURLWithPath: appPath).lastPathComponent)
                            .foregroundColor(appPath.isEmpty ? .secondary : .primary)

                        Spacer()

                        Button("Browse...") {
                            selectApplication()
                        }
                    }

                case .runShellCommand:
                    TextField("Shell Command", text: $shellCommand)
                    Text("Example: open -a Safari")
                        .font(.caption)
                        .foregroundColor(.secondary)

                case .internalCommand:
                    Picker("Command", selection: $selectedInternalCommand) {
                        ForEach(InternalCommand.allCases, id: \.self) { command in
                            HStack {
                                Image(systemName: command.iconName)
                                Text(command.displayName)
                            }
                            .tag(command)
                        }
                    }
                    Text(selectedInternalCommand.commandDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .onChange(of: selectedInternalCommand) { _, newCommand in
                // Auto-populate title and icon when internal command changes
                if title.isEmpty || InternalCommand.allCases.map({ $0.displayName }).contains(title) {
                    title = newCommand.displayName
                }
                iconName = newCommand.iconName
            }
            .onChange(of: actionType) { _, newType in
                // Auto-populate title and icon when switching to internal command
                if newType == .internalCommand {
                    if title.isEmpty {
                        title = selectedInternalCommand.displayName
                    }
                    iconName = selectedInternalCommand.iconName
                }
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    let action: ActionType
                    switch actionType {
                    case .launchApp:
                        action = .launchApp(path: appPath)
                    case .runShellCommand:
                        action = .runShellCommand(command: shellCommand)
                    case .internalCommand:
                        action = .internalCommand(selectedInternalCommand)
                    }

                    let newItem = MenuItem(
                        title: title.isEmpty ? "New Item" : title,
                        iconName: iconName,
                        action: action
                    )
                    onAdd(newItem)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || (actionType == .launchApp && appPath.isEmpty) || (actionType == .runShellCommand && shellCommand.isEmpty))
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .padding()
    }

    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.title = "Select Application"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            appPath = url.path
            selectedAppIcon = NSWorkspace.shared.icon(forFile: url.path)

            // Auto-populate title if empty
            if title.isEmpty {
                title = url.deletingPathExtension().lastPathComponent
            }
        }
    }
}

// Preview removed in CLI build to avoid macro plugin dependency.
