//
//  IconSetImportView.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import SwiftUI

/// View for importing custom icon sets
struct IconSetImportView: View {
    let iconSetProvider: IconSetProviderProtocol
    let onDismiss: () -> Void

    @State private var selectedFolder: URL?
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var validationResult: IconSetValidator.ValidationResult?

    var body: some View {
        VStack(spacing: 20) {
            Text("Import Icon Set")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Select a folder containing your icon set. The folder must have:")
                    .font(.body)

                VStack(alignment: .leading, spacing: 4) {
                    Label("manifest.json - metadata and icon mappings", systemImage: "doc.text")
                    Label("icons/ folder - PDF icon files", systemImage: "folder")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Divider()

            // Folder selection
            HStack {
                Text("Source Folder:")
                Text(selectedFolder?.lastPathComponent ?? "None selected")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose...") {
                    chooseFolder()
                }
            }
            .padding(.horizontal)

            // Validation status
            if let result = validationResult {
                VStack(alignment: .leading, spacing: 4) {
                    if result.isValid {
                        Label("Valid icon set", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Invalid icon set", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)

                        ForEach(result.errors.indices, id: \.self) { index in
                            Text("• \(result.errors[index].localizedDescription)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    if !result.warnings.isEmpty {
                        Text("Warnings:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 4)

                        ForEach(result.warnings.indices, id: \.self) { index in
                            Text("• \(result.warnings[index].localizedDescription)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Import") {
                    importIconSet()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedFolder == nil || validationResult?.isValid != true || isImporting)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .padding()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the icon set folder containing manifest.json"

        if panel.runModal() == .OK {
            selectedFolder = panel.url
            errorMessage = nil

            // Validate the selected folder
            if let url = panel.url {
                validationResult = IconSetValidator.validate(directoryURL: url)
            }
        }
    }

    private func importIconSet() {
        guard let sourceURL = selectedFolder else { return }

        isImporting = true
        errorMessage = nil

        do {
            _ = try iconSetProvider.importIconSet(from: sourceURL)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            isImporting = false
        }
    }
}
