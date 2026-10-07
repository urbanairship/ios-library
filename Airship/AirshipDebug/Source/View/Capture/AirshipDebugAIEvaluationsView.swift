/* Copyright Airship and Contributors */

import SwiftUI
@_spi(AirshipInternal) import AirshipCore

/// Every on-device AI evaluation recorded since the capture was switched on: what the model
/// was asked, and what it answered.
///
/// One row per *evaluation*, not per display — a feature that re-evaluates (an embedded view
/// re-ranking as content comes and goes) appears more than once.
struct AirshipDebugAIEvaluationsView: View {

    let manager: any AirshipAI.InternalManager

    @ObservedObject
    private var consent = AirshipDebugCaptureConsent.shared

    @State
    private var records: [AirshipDebugAIEvaluationRecord] = []

    @State
    private var expanded: Set<UUID> = []

    /// Newest first by default: the record you just produced is the one you came to read.
    @State
    private var newestFirst = true

    private var recorder: AirshipDebugAIEvaluationRecorder { .shared }

    var body: some View {
        List {
            AirshipDebugCaptureGate(kind: .aiEvaluations) { enabled in
                if enabled {
                    recorder.store.resume()
                    recorder.start(manager: manager)
                } else {
                    Task {
                        await recorder.store.purge()
                        self.records = []
                        self.expanded = []
                    }
                }
            }

            if consent.isEnabled(.aiEvaluations) {
                Section {
                    if records.isEmpty {
                        Text(
                            "Nothing recorded yet. Trigger a feature that uses on-device AI "
                            + "— an in-app message with a display filter, or a scene text "
                            + "input — or run one from the sandboxes above."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedRecords) { record in
                            row(record)
                        }
                    }
                } header: {
                    Text("Evaluations")
                } footer: {
                    Text("Most recent 1000 kept. Tap a row for detail, long press to copy.")
                }
            }
        }
        .navigationTitle("Evaluation Log")
        .toolbar {
            if consent.isEnabled(.aiEvaluations), !records.isEmpty {
                Button {
                    newestFirst.toggle()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel(newestFirst ? "Sort oldest first" : "Sort newest first")
            }
        }
        .task {
            if consent.isEnabled(.aiEvaluations) {
                recorder.start(manager: manager)
            }
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    /// The store keeps records oldest first; the screen shows them either way round.
    private var sortedRecords: [AirshipDebugAIEvaluationRecord] {
        newestFirst ? records.reversed() : records
    }

    private func reload() async {
        guard consent.isEnabled(.aiEvaluations) else {
            records = []
            return
        }
        records = await recorder.store.load()
    }

    @ViewBuilder
    private func row(_ record: AirshipDebugAIEvaluationRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                record.outcome.icon
                Text(record.usage)
                    .bold()
            }

            Text(record.outcome.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                // A failed evaluation's error can run to a dozen lines. The collapsed row
                // is a scannable index, so cap it here — the full text is one tap away.
                .lineLimit(2)

            Text("\(record.durationMS) ms · \(record.attempts) attempt\(record.attempts == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(.tint)

            Text(record.date.formatted(date: .abbreviated, time: .standard))
                .font(.caption)
                .foregroundStyle(.secondary)

            if expanded.contains(record.id) {
                detail(record)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if expanded.contains(record.id) {
                expanded.remove(record.id)
            } else {
                expanded.insert(record.id)
            }
        }
        .contextMenu {
            Button {
                record.pasteboardText.pastleboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private func detail(_ record: AirshipDebugAIEvaluationRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            section("Instructions", record.instructions)
            section(
                "Context",
                record.contextItems.isEmpty
                ? "(empty)"
                : record.contextItems.joined(separator: "\n")
            )
            if !record.prompt.isEmpty {
                section("Prompt", record.prompt)
            }
            section(record.outcome.detailTitle, record.outcome.detail)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.tint)
            Text(body)
                .font(.system(size: 12, design: .monospaced))
                .airshipDebugSelectableText()
        }
    }
}

fileprivate extension AirshipDebugAIEvaluationRecord {
    /// The whole record as one block, for pasting into a ticket.
    var pasteboardText: String {
        var lines = [
            "usage: \(usage)",
            "date: \(date.formatted(.iso8601))",
            "durationMS: \(durationMS)",
            "attempts: \(attempts)",
            "instructions: \(instructions)",
            "context:"
        ]
        lines += contextItems.isEmpty ? ["  (empty)"] : contextItems.map { "  \($0)" }
        lines.append("prompt: \(prompt)")
        lines.append("\(outcome.detailTitle.lowercased()): \(outcome.detail)")
        return lines.joined(separator: "\n")
    }
}

fileprivate extension AirshipDebugAIEvaluationRecord.Outcome {

    var icon: some View {
        switch self {
        case .completed:
            return Image(systemName: "checkmark.circle").foregroundStyle(.green)
        case .skipped:
            return Image(systemName: "minus.circle").foregroundStyle(.yellow)
        case .failed:
            return Image(systemName: "xmark.circle").foregroundStyle(.red)
        }
    }

    var summary: String {
        switch self {
        case .completed(let output):
            "completed: \(output.replacingOccurrences(of: "\n", with: " "))"
        case .skipped(let reason): "skipped: \(reason)"
        case .failed(let error): "failed: \(error)"
        }
    }

    var detailTitle: String {
        switch self {
        case .completed: "Output"
        case .skipped: "Skipped"
        case .failed: "Error"
        }
    }

    var detail: String {
        switch self {
        case .completed(let output): output
        case .skipped(let reason): reason
        case .failed(let error): error
        }
    }
}
