/* Copyright Airship and Contributors */

import Combine
import SwiftUI
@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipAutomation
import AirshipBasement

// MARK: - Root list

struct AirshipDebugAIView: View {

    @StateObject private var viewModel: ViewModel

    init(manager: any AirshipAI.InternalManager) {
        _viewModel = StateObject(wrappedValue: ViewModel(manager: manager))
    }

    var body: some View {
        List {
            Section("Model") {
                CommonItems.infoRow(title: "Status", value: viewModel.availabilityLabel)
                if case .unavailable(let reason) = viewModel.availability {
                    CommonItems.infoRow(title: "Reason", value: reason.debugLabel)
                }
            }

            Section("Registered Usages") {
                if viewModel.usageKeys.isEmpty {
                    Text("None registered")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.usageKeys, id: \.self) { key in
                        CommonItems.navigationLink(
                            title: key,
                            route: .aiSub(.usage(key: key))
                        )
                    }
                }
            }
        }
        .navigationTitle("AI Debug")
        .onAppear { viewModel.setup() }
    }
}

extension AirshipDebugAIView {
    @MainActor final class ViewModel: ObservableObject {
        @Published var availability: AirshipAI.Availability = .unavailable(reason: .osVersion)

        // Schemas live on evaluations now, so there is no runtime registry to
        // enumerate — this is the list of usages the debug UI knows how to drive.
        let usageKeys: [String] = [
            InAppMessageFilterContext.filterUsage.rawValue
        ]

        let manager: any AirshipAI.InternalManager

        init(manager: any AirshipAI.InternalManager) {
            self.manager = manager
        }

        var availabilityLabel: String {
            switch availability {
            case .available: return "Available"
            case .unavailable: return "Unavailable"
            @unknown default: return "Unknown"
            }
        }

        func setup() {
            availability = manager.availability
        }
    }
}

// MARK: - Per-usage view

struct AirshipDebugAIUsageView: View {
    let usageKey: String
    let manager: any AirshipAI.InternalManager

    var body: some View {
        if usageKey == InAppMessageFilterContext.filterUsage.rawValue {
            AirshipDebugIAAFilterView(manager: manager)
        } else {
            Text("No debug UI for usage \"\(usageKey)\"")
                .foregroundStyle(.secondary)
                .navigationTitle("Usage: \(usageKey)")
        }
    }
}

// MARK: - IAA filter sandbox

struct AirshipDebugIAAFilterView: View {
    @StateObject private var viewModel: IAAFilterViewModel
    @FocusState private var keyboardActive: Bool

    init(manager: any AirshipAI.InternalManager) {
        _viewModel = StateObject(wrappedValue: IAAFilterViewModel(manager: manager))
    }

    var body: some View {
        List {
            Section {
                TextEditor(text: $viewModel.filterPrompt)
                    .focused($keyboardActive)
                    .frame(minHeight: 72)
                    .overlay(alignment: .topLeading) {
                        if viewModel.filterPrompt.isEmpty {
                            Text("e.g. Only show this if the user travels frequently for work")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            } header: {
                Text("AI Filter Prompt")
            }

            Section {
                Button {
                    keyboardActive = false
                    Task { await viewModel.runFilter() }
                } label: {
                    HStack {
                        Spacer()
                        Text("Evaluate")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(viewModel.isRunning || viewModel.messageName.isEmpty)
            }

            Section("Result") {
                if viewModel.isRunning {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Evaluating…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if let result = viewModel.result {
                    switch result {
                    case .filter(let allow, let reason):
                        HStack(spacing: 12) {
                            Image(systemName: allow ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(allow ? .green : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(allow ? "Allowed" : "Blocked")
                                    .font(.headline)
                                Text(reason)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    case .skipped(let reason):
                        Label("Skipped: \(reason)", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    case .failed(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("Not evaluated yet")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Test Message Details") {
                TextField("Message name", text: $viewModel.messageName)
                    .autocorrectionDisabled()
                    .focused($keyboardActive)

                TextEditor(text: $viewModel.extrasJSON)
                    .focused($keyboardActive)
                    .frame(minHeight: 60)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .overlay(alignment: .topLeading) {
                        if viewModel.extrasJSON.isEmpty {
                            Text("Extras: {\"key\": \"value\"}")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }

                TextEditor(text: $viewModel.campaignsJSON)
                    .focused($keyboardActive)
                    .frame(minHeight: 60)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .overlay(alignment: .topLeading) {
                        if viewModel.campaignsJSON.isEmpty {
                            Text("Campaigns: {\"campaign_name\": \"summer_promo\"}")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("User Context") {
                if viewModel.isFetchingContext {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Fetching context…")
                            .foregroundStyle(.secondary)
                    }
                } else if let items = viewModel.context?.items, !items.isEmpty {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(priorityLabel(item.priority))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(item.content)
                                .font(.system(.footnote, design: .monospaced))
                        }
                        .padding(.vertical, 2)
                    }
                } else {
                    Text("No context provided")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyboardActive = false }
            }
        }
        .navigationTitle("IAX Display Filter")
        .onAppear {
            Task { await viewModel.fetchContext() }
        }
    }

    private func priorityLabel(_ priority: AirshipAI.Context.Priority) -> String {
        switch priority {
        case .low: return "low priority"
        case .medium: return "medium priority"
        case .high: return "high priority"
        @unknown default: return "priority \(priority.rawValue)"
        }
    }
}

// MARK: - IAA Filter ViewModel

private enum FilterResult {
    case filter(allow: Bool, reason: String)
    case skipped(String)
    case failed(String)
}

@MainActor
private final class IAAFilterViewModel: ObservableObject {
    @Published var messageName: String = "Test Message"
    @Published var filterPrompt: String = ""
    @Published var extrasJSON: String = ""
    @Published var campaignsJSON: String = ""
    @Published var context: AirshipAI.Context? = nil
    @Published var isFetchingContext = false
    @Published var isRunning = false
    @Published var result: FilterResult?

    private let manager: any AirshipAI.InternalManager

    init(manager: any AirshipAI.InternalManager) {
        self.manager = manager
    }

    func fetchContext() async {
        isFetchingContext = true
        defer { isFetchingContext = false }

        let subject = makeSubject()
        context = await manager.fetchContext(for: InAppMessageFilterContext.filterUsage, subject: subject)
    }

    func runFilter() async {
        isRunning = true
        result = nil
        defer { isRunning = false }

        await fetchContext()

        let subject = makeSubject()
        let evaluation = InAppMessageFilterEvaluation(
            filterPrompt: filterPrompt,
            subject: subject
        )
        switch await manager.evaluate(evaluation) {
        case .completed(let output):
            result = .filter(allow: output.allow, reason: output.reason)
        case .skipped(let reason):
            result = .skipped(reason)
        case .failed(let error):
            result = .failed(error.localizedDescription)
        @unknown default:
            result = .skipped("Unexpected result")
        }
    }

    private func makeSubject() -> InAppMessageFilterContext {
        return InAppMessageFilterContext(
            name: messageName,
            extras: parseStringDict(extrasJSON),
            campaigns: parseStringDict(campaignsJSON)
        )
    }

    private func parseStringDict(_ json: String) -> AirshipJSON? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        return try? AirshipJSON.from(json: trimmed)
    }
}

// MARK: - Helpers

private extension AirshipAI.Availability.Reason {
    var debugLabel: String {
        switch self {
        case .osVersion: return "OS version too low (requires iOS 26)"
        case .deviceNotEligible: return "Device not eligible for Apple Intelligence"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence disabled in settings"
        case .modelNotReady: return "Model downloading or warming up"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AirshipDebugAIView(manager: PreviewAIManager())
    }
}

private final class PreviewAIManager: AirshipAI.InternalManager, @unchecked Sendable {
    var availability: AirshipAI.Availability { .unavailable(reason: .osVersion) }
    func setProvider<S: Sendable>(_ provider: (any AirshipAI.ContextProvider<S>)?, for usage: AirshipAI.Usage<S>) {}
    func setDefaultProvider(_ provider: (any AirshipAI.ContextProvider<Void>)?) {}
    func setModel(_ selector: AirshipAI.ModelSelector) {}
    func evaluate<E: AirshipAI.Evaluation>(_ evaluation: E) async -> AirshipAI.Result<E.Output> { .skipped(reason: "preview") }
    func registerModelFactory(_ factory: @MainActor @Sendable @escaping () -> any AirshipAI.Model) {}
    func fetchContext<S: Sendable>(for usage: AirshipAI.Usage<S>, subject: S) async -> AirshipAI.Context { .empty }
}
