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
                        Image(systemName: item.iconName)
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
}

#Preview {
    PreferencesView(
        configuration: .sample(),
        onResetToDefault: {
            print("Reset to default")
        }
    )
}
