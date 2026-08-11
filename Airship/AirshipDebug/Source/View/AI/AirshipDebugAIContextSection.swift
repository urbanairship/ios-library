/* Copyright Airship and Contributors */

import SwiftUI
@_spi(AirshipInternal) import AirshipCore

/// One editable context item in a debug sandbox (mirrors ``AirshipAI/Context/Item``).
struct AirshipDebugContextItem: Codable, Equatable, Identifiable {
    var id: UUID
    var content: String
    var priority: Double

    init(id: UUID = UUID(), content: String, priority: Double = 0) {
        self.id = id
        self.content = content
        self.priority = priority
    }
}

/// How a debug sandbox combines its editable items with the app's registered provider.
enum AirshipDebugContextMode: String, Codable, CaseIterable, Identifiable {
    /// Use only the app's registered context provider — production behavior.
    case providerOnly
    /// Provider context plus the editable items below (items win priority ties).
    case append
    /// Ignore the provider; use only the editable items.
    case override

    var id: String { rawValue }

    var label: String {
        switch self {
        case .providerOnly: return "Provider"
        case .append: return "Provider + custom"
        case .override: return "Custom only"
        }
    }
}

extension Array where Element == AirshipDebugContextItem {
    /// The non-empty items as an ``AirshipAI/Context``.
    var airshipContext: AirshipAI.Context {
        AirshipAI.Context(
            items: self
                .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { .init(content: $0.content, priority: $0.priority) }
        )
    }
}

/// Reusable "Context" section: pick where context comes from and, for the custom modes, edit
/// the items inline. Also renders the resolved context the next run will actually use, so the
/// override/append behavior is visible.
struct AirshipDebugAIContextSection: View {
    @Binding var mode: AirshipDebugContextMode
    @Binding var items: [AirshipDebugContextItem]

    /// The context the next run will use, as resolved by the view model, for the preview.
    let resolvedItems: [AirshipAI.Context.Item]?
    let isFetching: Bool
    var focus: FocusState<Bool>.Binding?

    var body: some View {
        Section {
            Picker("Source", selection: $mode) {
                ForEach(AirshipDebugContextMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            if mode != .providerOnly {
                ForEach($items) { $item in
                    AirshipDebugContextItemRow(item: $item, focus: focus)
                }
                .onDelete { items.remove(atOffsets: $0) }

                Button {
                    items.append(AirshipDebugContextItem(content: ""))
                } label: {
                    Label("Add context item", systemImage: "plus.circle")
                }
            }

            resolvedPreview
        } header: {
            HStack {
                Text("Context")
                Spacer()
#if !os(tvOS) && !os(macOS)
                if mode != .providerOnly && !items.isEmpty {
                    EditButton().font(.footnote)
                }
#endif
            }
        } footer: {
            Text(footerText)
        }
    }

    @ViewBuilder
    private var resolvedPreview: some View {
        if isFetching {
            HStack(spacing: 8) {
                ProgressView()
                Text("Fetching context…").foregroundStyle(.secondary)
            }
        } else if let items = resolvedItems, !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Resolved context sent to the model")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "priority \(item.priority)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(item.content)
                            .font(.system(.footnote, design: .monospaced))
                    }
                    .padding(.vertical, 2)
                }
            }
        } else {
            Text("No context resolved")
                .foregroundStyle(.secondary)
        }
    }

    private var footerText: String {
        switch mode {
        case .providerOnly:
            return "Uses the app's registered context provider, exactly as production would."
        case .append:
            return "Provider context plus the items above (added after, so they win priority ties when trimmed)."
        case .override:
            return "Ignores the provider entirely and sends only the items above. Restored when you leave this screen."
        }
    }
}

/// One editable context item row: free-text content plus a priority stepper.
struct AirshipDebugContextItemRow: View {
    @Binding var item: AirshipDebugContextItem
    var focus: FocusState<Bool>.Binding?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            contentField
            HStack {
                Text("priority")
                    .font(.caption)
                    .foregroundStyle(.secondary)
#if !os(tvOS)
                Stepper(value: $item.priority, step: 1) {
                    Text("\(Int(item.priority))")
                        .font(.caption.monospacedDigit())
                }
#else
                Text("\(Int(item.priority))")
                    .font(.caption.monospacedDigit())
#endif
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var contentField: some View {
        if let focus {
            TextField("Context item, e.g. User interests: dogs", text: $item.content, axis: .vertical)
                .font(.system(.footnote, design: .monospaced))
                .freeInput()
                .focused(focus)
        } else {
            TextField("Context item, e.g. User interests: dogs", text: $item.content, axis: .vertical)
                .font(.system(.footnote, design: .monospaced))
                .freeInput()
        }
    }
}

/// Shows the assembled system instructions and rendered user prompt for a usage, so the exact
/// text sent to the model is visible before running.
struct AirshipDebugAIPromptPreview: View {
    let instructions: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            block("Instructions (system)", instructions)
            block("Prompt (user)", prompt)
        }
    }

    @ViewBuilder
    private func block(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text.isEmpty ? "—" : text)
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
#if !os(tvOS)
                .textSelection(.enabled)
#endif
        }
    }
}

// MARK: - Previews

private struct AirshipDebugAIContextSectionPreview: View {
    @State var mode: AirshipDebugContextMode
    @State var items: [AirshipDebugContextItem]
    let resolvedItems: [AirshipAI.Context.Item]?
    let isFetching: Bool

    var body: some View {
        Form {
            AirshipDebugAIContextSection(
                mode: $mode,
                items: $items,
                resolvedItems: resolvedItems,
                isFetching: isFetching,
                focus: nil
            )
        }
    }
}

#Preview("Context – custom items") {
    AirshipDebugAIContextSectionPreview(
        mode: .override,
        items: [
            AirshipDebugContextItem(content: "User interests: dogs, hiking", priority: 1),
            AirshipDebugContextItem(content: "Last purchase: 2-person tent", priority: 0)
        ],
        resolvedItems: [
            .init(content: "User interests: dogs, hiking", priority: 1),
            .init(content: "Last purchase: 2-person tent", priority: 0)
        ],
        isFetching: false
    )
}

#Preview("Context – provider, fetching") {
    AirshipDebugAIContextSectionPreview(
        mode: .providerOnly,
        items: [],
        resolvedItems: nil,
        isFetching: true
    )
}

#Preview("Prompt preview") {
    Form {
        AirshipDebugAIPromptPreview(
            instructions: "You decide whether to suppress a message. Fail open: when unsure, allow.",
            prompt: "User has opened the app 12 times today. Suppress the promo?"
        )
    }
}
