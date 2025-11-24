//
//  PreferencesView.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import SwiftUI

/// Preferences window view
struct PreferencesView: View {
    let configuration: MenuConfiguration
    let onResetToDefault: () -> Void
    let onUpdateIconSet: (IconSet) -> Void
    let onUpdateBackgroundColor: (CodableColor) -> Void
    let onUpdateForegroundColor: (CodableColor) -> Void

    @State private var selectedIconSet: IconSet
    @State private var backgroundColor: Color
    @State private var foregroundColor: Color

    init(
        configuration: MenuConfiguration,
        onResetToDefault: @escaping () -> Void,
        onUpdateIconSet: @escaping (IconSet) -> Void,
        onUpdateBackgroundColor: @escaping (CodableColor) -> Void,
        onUpdateForegroundColor: @escaping (CodableColor) -> Void
    ) {
        self.configuration = configuration
        self.onResetToDefault = onResetToDefault
        self.onUpdateIconSet = onUpdateIconSet
        self.onUpdateBackgroundColor = onUpdateBackgroundColor
        self.onUpdateForegroundColor = onUpdateForegroundColor
        _selectedIconSet = State(initialValue: configuration.appearanceSettings.iconSet)
        _backgroundColor = State(initialValue: configuration.appearanceSettings.backgroundColor.color)
        _foregroundColor = State(initialValue: configuration.appearanceSettings.foregroundColor.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Radial Menu Preferences")
                .font(.title2)
                .fontWeight(.bold)

            Divider()

            // Menu Items Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Items")
                    .font(.headline)

                List(configuration.items) { item in
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
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 200)
            }

            // Appearance Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.headline)

                HStack {
                    Text("Icon Set:")
                    Picker("Icon Set", selection: $selectedIconSet) {
                        ForEach(IconSet.allCases, id: \.self) { set in
                            Text(set.displayName).tag(set)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedIconSet) { _, newValue in
                        onUpdateIconSet(newValue)
                    }
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
                    Text("Radius:")
                    Text("\(Int(configuration.appearanceSettings.radius))px")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Center Radius:")
                    Text("\(Int(configuration.appearanceSettings.centerRadius))px")
                        .foregroundColor(.secondary)
                }
            }

            // Behavior Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Behavior")
                    .font(.headline)

                HStack {
                    Text("Position Mode:")
                    Text(configuration.behaviorSettings.positionMode == .atCursor ? "At Cursor" : "Fixed")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Show on All Spaces:")
                    Text(configuration.behaviorSettings.showOnAllSpaces ? "Yes" : "No")
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

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
        }
        .padding(20)
        .frame(width: 500, height: 600)
    }

    private func iconImage(for item: MenuItem) -> Image {
        let resolved = item.resolvedIcon(for: selectedIconSet)
        if resolved.isSystem {
            return Image(systemName: resolved.name)
        } else {
            return Image(resolved.name)
        }
    }
}

// Preview removed in CLI build to avoid macro plugin dependency.
