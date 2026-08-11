/* Copyright Airship and Contributors */

import SwiftUI

/// Reusable "Test Data" section shared by the AI debug sandboxes.
///
/// Lets you drop in a built-in example or a saved preset, save the current inputs as a new
/// preset, and import/export inputs as JSON to share a case with someone else. Autosave of
/// the working session is handled by the owning view model — this is only the explicit,
/// named test-data management.
struct AirshipDebugAITestDataSection<State: Codable & Equatable>: View {
    @ObservedObject var store: AirshipDebugAIStore<State>

    /// The sandbox's current inputs, captured when saving or exporting.
    let currentState: () -> State

    /// Applies a chosen example/preset/import back into the sandbox.
    let onLoad: (State) -> Void

    @State private var showingSave = false
    @State private var presetName = ""
    @State private var showingImport = false
    @State private var importText = ""
    @State private var showingExport = false

    var body: some View {
        Section {
            Menu {
                if store.bundledFixtures.isEmpty {
                    Text("No examples")
                } else {
                    ForEach(store.bundledFixtures) { fixture in
                        Button(fixture.name) { onLoad(fixture.state) }
                    }
                }
            } label: {
                Label("Load example", systemImage: "tray.and.arrow.down")
            }

            if !store.presets.isEmpty {
                ForEach(store.presets) { preset in
                    Button {
                        onLoad(preset.state)
                    } label: {
                        Label(preset.name, systemImage: "bookmark")
                    }
                }
                .onDelete { store.deletePresets(at: $0) }
            }

            Button {
                presetName = ""
                showingSave = true
            } label: {
                Label("Save current as preset…", systemImage: "plus.circle")
            }

            Button {
                showingExport = true
            } label: {
                Label("Export JSON", systemImage: "square.and.arrow.up")
            }

            Button {
                importText = ""
                showingImport = true
            } label: {
                Label("Import JSON…", systemImage: "square.and.arrow.down")
            }
        } header: {
            HStack {
                Text("Test Data")
                Spacer()
#if !os(tvOS) && !os(macOS)
                if !store.presets.isEmpty {
                    EditButton().font(.footnote)
                }
#endif
            }
        } footer: {
            Text("Inputs auto-save and restore next time. Save named presets or import/export JSON to share cases.")
        }
        .sheet(isPresented: $showingSave) { savePresetSheet }
        .sheet(isPresented: $showingImport) { importSheet }
        .sheet(isPresented: $showingExport) { exportSheet }
    }

    private var savePresetSheet: some View {
        NavigationStack {
            Form {
                Section("Preset name") {
                    TextField("Name", text: $presetName)
                        .freeInput()
                }
            }
            .navigationTitle("Save Preset")
#if !os(tvOS) && !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSave = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.savePreset(name: presetName, state: currentState())
                        showingSave = false
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var exportSheet: some View {
        NavigationStack {
            ScrollView {
                Text(store.exportJSON(currentState()) ?? "Failed to encode state.")
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
#if !os(tvOS)
                    .textSelection(.enabled)
#endif
            }
            .navigationTitle("Export JSON")
#if !os(tvOS) && !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if !os(tvOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Copy") { (store.exportJSON(currentState()) ?? "").pastleboard() }
                }
#endif
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingExport = false }
                }
            }
        }
    }

    private var importSheet: some View {
        NavigationStack {
            Form {
                Section {
#if os(tvOS)
                    TextField("Paste JSON", text: $importText)
#else
                    TextEditor(text: $importText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 200)
#endif
                } header: {
                    Text("Paste exported JSON")
                } footer: {
                    if !importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       store.importJSON(importText) == nil {
                        Text("Not valid JSON for this screen.")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Import JSON")
#if !os(tvOS) && !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingImport = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        if let state = store.importJSON(importText) {
                            onLoad(state)
                            showingImport = false
                        }
                    }
                    .disabled(store.importJSON(importText) == nil)
                }
            }
        }
    }
}

/// Reusable "Run History" section: the last handful of runs for a usage, tap-to-restore.
struct AirshipDebugAIHistorySection<State: Codable & Equatable>: View {
    @ObservedObject var store: AirshipDebugAIStore<State>

    /// Restores a past run's inputs into the sandbox.
    let onRestore: (State) -> Void

    var body: some View {
        Section {
            if store.history.isEmpty {
                Text("No runs yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.history) { record in
                    Button {
                        onRestore(record.state)
                    } label: {
                        row(record)
                    }
                }

                Button(role: .destructive) {
                    store.clearHistory()
                } label: {
                    Label("Clear history", systemImage: "trash")
                }
            }
        } header: {
            Text("Run History")
        } footer: {
            Text("Tap a run to restore its inputs.")
        }
    }

    private func row(_ record: AirshipDebugAIStore<State>.RunRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.summary.isEmpty ? "(run)" : record.summary)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(record.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(record.output)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Previews

private struct DebugAITestDataPreviewState: Codable, Equatable {
    var text: String = ""
}

#Preview("Test Data + History") {
    let store = AirshipDebugAIStore<DebugAITestDataPreviewState>(
        usageKey: "preview",
        bundledFixtures: [
            .init(name: "Example: greeting", state: .init(text: "hello")),
            .init(name: "Example: empty", state: .init(text: ""))
        ],
        directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("ua-debug-ai-preview-\(UUID().uuidString)", isDirectory: true)
    )
    store.savePreset(name: "My saved case", state: .init(text: "saved input"))
    store.recordRun(
        summary: "Ran greeting",
        output: "{ \"suppress\": false }",
        state: .init(text: "hello")
    )

    return Form {
        AirshipDebugAITestDataSection(
            store: store,
            currentState: { DebugAITestDataPreviewState(text: "current input") },
            onLoad: { _ in }
        )
        AirshipDebugAIHistorySection(store: store, onRestore: { _ in })
    }
}
