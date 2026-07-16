/* Copyright Airship and Contributors */

import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// A JSON text editor with inline validity feedback and a one-tap formatter.
///
/// Used across the AI debug sandboxes for free-form JSON (context extras, campaigns, and
/// the raw-schema escape hatch). Empty input is treated as valid (means "none").
struct AirshipDebugJSONEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var focus: FocusState<Bool>.Binding?

    @State private var minHeight: CGFloat = 90

    private var validity: Validity {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        do {
            _ = try AirshipJSON.from(json: trimmed)
            return .valid
        } catch {
            return .invalid
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                validityBadge
                Button("Format") { format() }
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .disabled(validity != .valid)
            }

            editor
                .frame(minHeight: minHeight)
                .font(.system(.footnote, design: .monospaced))
                .freeInput()
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var editor: some View {
        if let focus {
            TextEditor(text: $text).focused(focus)
        } else {
            TextEditor(text: $text)
        }
    }

    @ViewBuilder
    private var validityBadge: some View {
        switch validity {
        case .empty:
            EmptyView()
        case .valid:
            Label("Valid", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
                .labelStyle(.iconOnly)
        case .invalid:
            Label("Invalid JSON", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }

    private var borderColor: Color {
        switch validity {
        case .invalid: return .orange.opacity(0.7)
        default: return .secondary.opacity(0.25)
        }
    }

    private func format() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = trimmed.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            ),
            let string = String(data: pretty, encoding: .utf8)
        else {
            return
        }
        text = string
    }

    private enum Validity: Equatable {
        case empty
        case valid
        case invalid
    }
}
