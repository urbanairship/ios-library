/* Copyright Airship and Contributors */

import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Airship SDK log messages recorded since the capture was switched on.
///
/// Reads the same stream the app's own log handler sees, through a tap, so an app that set
/// `AirshipConfig.logHandler` keeps it and loses nothing.
struct AirshipDebugLogsView: View {

    @ObservedObject
    private var consent = AirshipDebugCaptureConsent.shared

    @State
    private var records: [AirshipDebugLogRecord] = []

    @State
    private var levelFilter: String? = nil

    @State
    private var newestFirst = true

    private var recorder: AirshipDebugLogRecorder { .shared }

    /// The store keeps records oldest first; the screen shows them either way round.
    private var filtered: [AirshipDebugLogRecord] {
        let matching = levelFilter.map { level in
            records.filter { $0.level == level }
        } ?? records
        return newestFirst ? matching.reversed() : matching
    }

    var body: some View {
        List {
            AirshipDebugCaptureGate(kind: .logs) { enabled in
                recorder.setRecording(enabled)
                if enabled {
                    recorder.start()
                } else {
                    Task {
                        await recorder.store.purge()
                        self.records = []
                    }
                }
            }

            if consent.isEnabled(.logs) {
                Section {
                    Picker("Level", selection: $levelFilter) {
                        Text("All").tag(String?.none)
                        ForEach(Self.filterableLevels, id: \.self) { level in
                            Text(level.capitalized).tag(String?.some(level))
                        }
                    }
                }

                Section {
                    if filtered.isEmpty {
                        Text(
                            records.isEmpty
                            ? "Nothing recorded yet."
                            : "No messages at this level."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(filtered) { record in
                            row(record)
                        }
                    }
                } header: {
                    Text("Messages")
                } footer: {
                    Text("Most recent 1000 kept. Long press a message to copy.")
                }
            }
        }
        .navigationTitle("Logs")
        .toolbar {
            if consent.isEnabled(.logs), !records.isEmpty {
                Button {
                    newestFirst.toggle()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel(newestFirst ? "Sort oldest first" : "Sort newest first")
            }
        }
        .task {
            recorder.start()
            recorder.setRecording(consent.isEnabled(.logs))
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private static let filterableLevels = ["error", "warn", "info", "debug", "verbose"]

    private func reload() async {
        guard consent.isEnabled(.logs) else {
            records = []
            return
        }
        records = await recorder.store.load()
    }

    @ViewBuilder
    private func row(_ record: AirshipDebugLogRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Self.icon(for: record.level)
                Text(record.message)
                    .font(.footnote)
            }

            Text("\(record.fileID) \(record.function) [line \(record.line)]")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(record.date.formatted(date: .abbreviated, time: .standard))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .airshipDebugSelectableText()
        .contextMenu {
            Button {
                record.pasteboardText.pastleboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private static func icon(for level: String) -> some View {
        switch level {
        case "error":
            Image(systemName: "xmark.circle").foregroundStyle(.red)
        case "warn":
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.yellow)
        default:
            Image(systemName: "info.circle").foregroundStyle(.blue)
        }
    }
}

fileprivate extension AirshipDebugLogRecord {
    /// One line per message, in the shape the console prints — so a copied message reads
    /// the same as one grepped out of a device log.
    var pasteboardText: String {
        "[\(level)] \(date.formatted(.iso8601)) \(fileID) \(function) [line \(line)] \(message)"
    }
}
