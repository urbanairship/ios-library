/* Copyright Airship and Contributors */

import Foundation
import Combine
import SwiftUI

/// Per-usage persistence for an AI debug sandbox.
///
/// Keeps three things as JSON files on disk, namespaced by usage key:
/// - the last-entered session, auto-restored when the screen reappears,
/// - user-saved presets, and
/// - a short run history.
///
/// Debug-only, so there is no migration story: data that no longer decodes (e.g. after the
/// `State` shape changes) is simply ignored and treated as absent.
@MainActor
final class AirshipDebugAIStore<State: Codable & Equatable>: ObservableObject {

    /// A named, reusable snapshot of a sandbox's inputs.
    struct Preset: Codable, Identifiable, Equatable {
        var id: UUID
        var name: String
        var state: State

        init(id: UUID = UUID(), name: String, state: State) {
            self.id = id
            self.name = name
            self.state = state
        }
    }

    /// One recorded run: the inputs that produced it plus a short summary and the output.
    struct RunRecord: Codable, Identifiable, Equatable {
        var id: UUID
        var date: Date
        var summary: String
        var output: String
        var state: State

        init(
            id: UUID = UUID(),
            date: Date = Date(),
            summary: String,
            output: String,
            state: State
        ) {
            self.id = id
            self.date = date
            self.summary = summary
            self.output = output
            self.state = state
        }
    }

    /// Built-in example cases supplied by the screen. Not persisted — always available.
    let bundledFixtures: [Preset]

    @Published private(set) var presets: [Preset] = []
    @Published private(set) var history: [RunRecord] = []

    private let usageKey: String
    private let directory: URL
    private let historyLimit: Int

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        usageKey: String,
        bundledFixtures: [Preset] = [],
        historyLimit: Int = 10,
        directory: URL? = nil
    ) {
        self.usageKey = usageKey
        self.bundledFixtures = bundledFixtures
        self.historyLimit = historyLimit
        self.directory = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
        self.presets = load([Preset].self, for: .presets) ?? []
        self.history = load([RunRecord].self, for: .history) ?? []
    }

    // MARK: - Last session

    func loadLastSession() -> State? {
        load(State.self, for: .lastSession)
    }

    func saveLastSession(_ state: State) {
        save(state, for: .lastSession)
    }

    // MARK: - Presets

    @discardableResult
    func savePreset(name: String, state: State) -> Preset {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = Preset(name: trimmed.isEmpty ? "Untitled" : trimmed, state: state)
        presets.append(preset)
        save(presets, for: .presets)
        return preset
    }

    func deletePresets(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        save(presets, for: .presets)
    }

    // MARK: - History

    func recordRun(summary: String, output: String, state: State) {
        history.insert(RunRecord(summary: summary, output: output, state: state), at: 0)
        if history.count > historyLimit {
            history.removeLast(history.count - historyLimit)
        }
        save(history, for: .history)
    }

    func clearHistory() {
        history.removeAll()
        save(history, for: .history)
    }

    // MARK: - Import / export

    /// A shareable, pretty-printed JSON representation of a state, for export.
    func exportJSON(_ state: State) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(state) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decodes a state from exported JSON, or nil when the text isn't a valid state.
    func importJSON(_ json: String) -> State? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return nil }
        return try? decoder.decode(State.self, from: data)
    }

    // MARK: - Storage

    private enum Slot: String {
        case lastSession = "last_session"
        case presets
        case history
    }

    /// Shared directory for every sandbox's files, under Application Support.
    private static func defaultDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("com.urbanairship.debug.ai", isDirectory: true)
    }

    /// One file per usage + slot, e.g. `embedded_selection.presets.json`.
    private func fileURL(_ slot: Slot) -> URL {
        directory.appendingPathComponent("\(usageKey).\(slot.rawValue).json")
    }

    private func save<T: Encodable>(_ value: T, for slot: Slot) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL(slot), options: .atomic)
    }

    private func load<T: Decodable>(_ type: T.Type, for slot: Slot) -> T? {
        guard let data = try? Data(contentsOf: fileURL(slot)) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
