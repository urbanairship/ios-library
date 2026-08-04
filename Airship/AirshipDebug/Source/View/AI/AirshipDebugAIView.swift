/* Copyright Airship and Contributors */

import Combine
import SwiftUI
@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipAutomation
@_spi(AirshipInternal) import AirshipScenes
@_spi(AirshipInternal) import AirshipSceneRenderer
import AirshipBasement

// MARK: - Root list

struct AirshipDebugAIView: View {

    @StateObject private var viewModel: ViewModel

    init(manager: any AirshipAI.InternalManager) {
        _viewModel = StateObject(wrappedValue: ViewModel(manager: manager))
    }

    var body: some View {
        List {
            Section("Usages") {
                if viewModel.usageKeys.isEmpty {
                    Text("None registered")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.usageKeys, id: \.self) { key in
                        VStack(alignment: .leading, spacing: 2) {
                            CommonItems.navigationLink(
                                title: key,
                                route: .aiSub(.usage(key: key))
                            )
                            Text(viewModel.availabilityLabel(for: key))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
        @Published var availabilityByUsage: [String: AirshipAI.Availability] = [:]

        // Schemas live on evaluations now, so there is no runtime registry to
        // enumerate — this is the list of usages the debug UI knows how to drive.
        let usageKeys: [String] = [
            AirshipAI.InAppMessageSuppression.usage.rawValue,
            AirshipAI.TextInputInference.usage.rawValue,
            AirshipAI.EmbeddedSelection.usage.rawValue,
        ]

        let manager: any AirshipAI.InternalManager
        private var observationTasks: [String: Task<Void, Never>] = [:]

        init(manager: any AirshipAI.InternalManager) {
            self.manager = manager
        }

        func availabilityLabel(for usageKey: String) -> String {
            switch availabilityByUsage[usageKey] {
            case .available: return "Available"
            case .unavailable(let reason): return "Unavailable — \(reason.debugLabel)"
            case nil: return "No model"
            @unknown default: return "Unknown"
            }
        }

        func setup() {
            observe(usage: AirshipAI.InAppMessageSuppression.usage)
            observe(usage: AirshipAI.TextInputInference.usage)
            observe(usage: AirshipAI.EmbeddedSelection.usage)
        }

        private func observe<S: Sendable>(usage: AirshipAI.Usage<S>) {
            let key = usage.rawValue
            observationTasks[key]?.cancel()
            guard let stream = manager.model(for: usage)?.availabilityUpdates else { return }
            observationTasks[key] = Task { [weak self] in
                for await availability in stream {
                    if Task.isCancelled { break }
                    self?.availabilityByUsage[key] = availability
                }
            }
        }
    }
}

// MARK: - Per-usage view

struct AirshipDebugAIUsageView: View {
    let usageKey: String
    let manager: any AirshipAI.InternalManager

    var body: some View {
        if usageKey == AirshipAI.InAppMessageSuppression.usage.rawValue {
            AirshipDebugIAASuppressionView(manager: manager)
        } else if usageKey == AirshipAI.TextInputInference.usage.rawValue {
            AirshipDebugSceneTextInputView(manager: manager)
        } else if usageKey == AirshipAI.EmbeddedSelection.usage.rawValue {
            AirshipDebugEmbeddedSelectionView(manager: manager)
        } else {
            Text("No debug UI for usage \"\(usageKey)\"")
                .foregroundStyle(.secondary)
                .navigationTitle("Usage: \(usageKey)")
        }
    }
}

// MARK: - IAA suppression sandbox

fileprivate struct AirshipDebugIAASuppressionView: View {
    @StateObject private var viewModel: IAASuppressionViewModel
    @FocusState private var keyboardActive: Bool

    init(manager: any AirshipAI.InternalManager) {
        _viewModel = StateObject(wrappedValue: IAASuppressionViewModel(manager: manager))
    }

    var body: some View {
        List {
            Section {
#if os(tvOS)
                TextField("e.g. Only show this if the user travels frequently for work", text: $viewModel.condition)
                    .focused($keyboardActive)
#else
                TextEditor(text: $viewModel.condition)
                    .focused($keyboardActive)
                    .frame(minHeight: 72)
                    .overlay(alignment: .topLeading) {
                        if viewModel.condition.isEmpty {
                            Text("e.g. Only show this if the user travels frequently for work")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
#endif
            } header: {
                Text("Condition")
            } footer: {
                Text("Injected into the SDK's fixed instruction template.")
            }

            Section("Generated Instructions") {
                Text(viewModel.generatedInstructions)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
#if !os(tvOS)
                    .textSelection(.enabled)
#endif
            }

            Section("Test Message Details") {
                TextField("Message name", text: $viewModel.messageName)
                    .autocorrectionDisabled()
                    .focused($keyboardActive)

                AirshipDebugJSONEditor(
                    title: "Extras",
                    placeholder: "{\"key\": \"value\"}",
                    text: $viewModel.extrasJSON,
                    focus: $keyboardActive
                )

                AirshipDebugJSONEditor(
                    title: "Subject Hints",
                    placeholder: "{\"hint_key\": \"hint_value\"}",
                    text: $viewModel.hintsJSON,
                    focus: $keyboardActive
                )
            }

            Section {
                Button {
                    keyboardActive = false
                    Task { await viewModel.runEvaluation() }
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
                    case .completed(let allow, let reason):
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
#if os(iOS)
        // Keyboard-dismiss gesture and the `.keyboard` toolbar placement exist
        // only on iOS / Mac Catalyst (not macOS, tvOS, or visionOS).
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyboardActive = false }
            }
        }
#endif
        .navigationTitle("IAX AI Suppression")
        .onAppear {
            Task { await viewModel.fetchContext() }
        }
    }

    private func priorityLabel(_ priority: Double) -> String {
        "priority \(priority)"
    }
}

// MARK: - IAA Suppression ViewModel

private enum SuppressionResult {
    case completed(allow: Bool, reason: String)
    case skipped(String)
    case failed(String)
}

@MainActor
private final class IAASuppressionViewModel: ObservableObject {
    @Published var messageName: String = "Test Message"
    @Published var condition: String = ""
    @Published var extrasJSON: String = ""
    @Published var hintsJSON: String = ""
    @Published var context: AirshipAI.Context? = nil
    @Published var isFetchingContext = false
    @Published var isRunning = false
    @Published var result: SuppressionResult?

    private let manager: any AirshipAI.InternalManager

    init(manager: any AirshipAI.InternalManager) {
        self.manager = manager
    }

    func fetchContext() async {
        isFetchingContext = true
        defer { isFetchingContext = false }

        let subject = makeSubject()
        context = await manager.fetchContext(for: AirshipAI.InAppMessageSuppression.usage, subject: subject)
    }

    func runEvaluation() async {
        isRunning = true
        result = nil
        defer { isRunning = false }

        await fetchContext()

        let subject = makeSubject()
        let evaluation = InAppMessageAISuppressionEvaluation(
            condition: condition,
            subject: subject
        )
        switch await manager.evaluate(evaluation) {
        case .completed(let output):
            result = .completed(allow: output.allow, reason: output.reason)
        case .skipped(let reason):
            result = .skipped(reason)
        case .failed(let error):
            result = .failed(error.localizedDescription)
        @unknown default:
            result = .skipped("Unexpected result")
        }
    }

    /// The full instruction text the SDK will send — the fixed template with the current
    /// condition injected. Shown in the debug UI so the combined prompt is visible.
    var generatedInstructions: String {
        InAppMessageAISuppressionEvaluation(
            condition: condition,
            subject: makeSubject()
        ).instructions()
    }

    private func makeSubject() -> AirshipAI.InAppMessageSuppression.Subject {
        let hints = (try? JSONDecoder().decode([String: String].self, from: Data(hintsJSON.utf8))) ?? [:]
        return AirshipAI.InAppMessageSuppression.Subject(
            name: messageName,
            extras: parseStringDict(extrasJSON),
            priority: 0,
            hints: hints
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
        case .deviceNotEligible: return "Device or OS can't run the model"
        case .missingModel: return "No model available (not downloaded or still preparing)"
        case .notEnabled: return "AI features are turned off"
        case .other(let message): return message
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Embedded selection sandbox

struct AirshipDebugEmbeddedSelectionView: View {
    @StateObject private var viewModel: EmbeddedSelectionViewModel
    @FocusState private var keyboardActive: Bool

    init(manager: any AirshipAI.InternalManager) {
        _viewModel = StateObject(wrappedValue: EmbeddedSelectionViewModel(manager: manager))
    }

    var body: some View {
        List {
            Section {
#if os(tvOS)
                TextField("e.g. Show content that matches the user's interests.", text: $viewModel.prompt)
                    .focused($keyboardActive)
#else
                TextEditor(text: $viewModel.prompt)
                    .focused($keyboardActive)
                    .frame(minHeight: 72)
                    .overlay(alignment: .topLeading) {
                        if viewModel.prompt.isEmpty {
                            Text("e.g. Show content that matches the user's interests.")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
#endif
            } header: {
                Text("Prompt")
            } footer: {
                Text("Passed verbatim as the author instruction to the model.")
            }

            Section {
                ForEach($viewModel.candidates) { $candidate in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Instance ID", text: $candidate.instanceID)
                                .autocorrectionDisabled()
                                .focused($keyboardActive)
                            Spacer()
#if !os(tvOS)
                            Stepper("Priority \(candidate.priority)", value: $candidate.priority)
                                .labelsHidden()
#endif
                            Text("P\(candidate.priority)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                        }
                        AirshipDebugJSONEditor(
                            title: "Extras",
                            placeholder: "{\"description\": \"...\"}",
                            text: $candidate.extrasJSON,
                            focus: $keyboardActive
                        )
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { viewModel.candidates.remove(atOffsets: $0) }

                Button {
                    viewModel.addCandidate()
                } label: {
                    Label("Add candidate", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Candidates")
                    Spacer()
#if !os(tvOS) && !os(macOS)
                    EditButton()
                        .font(.footnote)
#endif
                }
            }

            Section {
                Button {
                    keyboardActive = false
                    Task { await viewModel.rank() }
                } label: {
                    HStack {
                        Spacer()
                        Text("Rank").bold()
                        Spacer()
                    }
                }
                .disabled(viewModel.isRunning || viewModel.candidates.count < 2 || viewModel.prompt.isEmpty)
            }

            Section("Result") {
                if viewModel.isRunning {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Ranking…").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if let result = viewModel.result {
                    switch result {
                    case .ranked(let scores, let reason):
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(scores.enumerated()), id: \.offset) { index, entry in
                                HStack(spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    Text(entry.id)
                                        .font(.system(.footnote, design: .monospaced))
                                    Spacer()
                                    Text("score: \(entry.score)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(reason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
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
                    Text("Not ranked yet").foregroundStyle(.secondary)
                }
            }

            Section("Model Status & Context") {
                CommonItems.infoRow(title: "Availability", value: viewModel.availabilityLabel)
                if viewModel.isFetchingContext {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Fetching context…").foregroundStyle(.secondary)
                    }
                } else if let items = viewModel.context?.items, !items.isEmpty {
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
                } else {
                    Text("No context provided").foregroundStyle(.secondary)
                }
            }
        }
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { keyboardActive = false }
            }
        }
#endif
        .navigationTitle("Embedded Selection")
        .onAppear {
            viewModel.observeAvailability()
            Task { await viewModel.fetchContext() }
        }
    }
}

private enum EmbeddedSelectionResult {
    case ranked([(id: String, score: Int)], reason: String)
    case skipped(String)
    case failed(String)
}

private struct EmbeddedCandidate: Identifiable {
    let id: UUID = UUID()
    var instanceID: String
    var extrasJSON: String
    var priority: Int
}

@MainActor
private final class EmbeddedSelectionViewModel: ObservableObject {
    @Published var prompt: String = "Show content that matches the user's interests."
    @Published var candidates: [EmbeddedCandidate] = [
        EmbeddedCandidate(instanceID: UUID().uuidString, extrasJSON: "{\"description\": \"Adopt a rescue cat today — find your perfect feline companion.\"}", priority: 0),
        EmbeddedCandidate(instanceID: UUID().uuidString, extrasJSON: "{\"description\": \"Top-rated dog food for active breeds — fuel your pup's adventures.\"}", priority: 1),
        EmbeddedCandidate(instanceID: UUID().uuidString, extrasJSON: "{\"description\": \"Spring sale on cat trees, toys, and grooming supplies.\"}", priority: 2),
    ]
    @Published var result: EmbeddedSelectionResult?
    @Published var isRunning = false
    @Published var isFetchingContext = false
    @Published var context: AirshipAI.Context?
    @Published var availability: AirshipAI.Availability = .unavailable(reason: .missingModel)

    private let manager: any AirshipAI.InternalManager
    private var availabilityTask: Task<Void, Never>?

    init(manager: any AirshipAI.InternalManager) {
        self.manager = manager
    }

    func addCandidate() {
        candidates.append(EmbeddedCandidate(instanceID: "id-\(candidates.count + 1)", extrasJSON: "", priority: 0))
    }

    func observeAvailability() {
        availabilityTask?.cancel()
        guard let stream = manager.model(for: AirshipAI.EmbeddedSelection.usage)?.availabilityUpdates else { return }
        availabilityTask = Task { [weak self] in
            for await value in stream {
                if Task.isCancelled { break }
                self?.availability = value
            }
        }
    }

    var availabilityLabel: String {
        switch availability {
        case .available: return "Available"
        case .unavailable(let reason): return "Unavailable (\(reason))"
        @unknown default: return "Unknown"
        }
    }

    func fetchContext() async {
        isFetchingContext = true
        defer { isFetchingContext = false }
        let subject = AirshipAI.EmbeddedSelection.Subject(
            embeddedID: "debug",
            pending: makeCandidateInfos(),
            hints: [:]
        )
        context = await manager.fetchContext(for: AirshipAI.EmbeddedSelection.usage, subject: subject)
    }

    func rank() async {
        isRunning = true
        result = nil
        defer { isRunning = false }

        await fetchContext()

        let request = EmbeddedAISelectionRequest(
            embeddedID: "debug",
            prompt: prompt,
            candidates: makeCandidateInfos()
        )
        let evaluation = EmbeddedSelectionEvaluation(request: request)

        switch await manager.evaluate(evaluation) {
        case .completed(let output):
            let priorityByID = Dictionary(uniqueKeysWithValues: makeCandidateInfos().map { ($0.instanceID, $0.priority) })
            let scored = output.scores
                .sorted { lhs, rhs in
                    if lhs.score != rhs.score { return lhs.score > rhs.score }
                    return (priorityByID[lhs.id] ?? .max) < (priorityByID[rhs.id] ?? .max)
                }
                .map { (id: $0.id, score: $0.score) }
            result = .ranked(scored, reason: output.reason)
        case .skipped(let reason):
            result = .skipped(reason)
        case .failed(let error):
            result = .failed(error.localizedDescription)
        @unknown default:
            result = .skipped("Unexpected result")
        }
    }

    private func makeCandidateInfos() -> [AirshipEmbeddedInfo] {
        candidates.map { candidate in
            AirshipEmbeddedInfo(
                instanceID: candidate.instanceID,
                embeddedID: "debug",
                extras: try? AirshipJSON.from(json: candidate.extrasJSON),
                priority: candidate.priority
            )
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
    var defaultModel: (any AirshipAI.Model)? { nil }
    func model<S: Sendable>(for usage: AirshipAI.Usage<S>) -> (any AirshipAI.Model)? { nil }
    func setContextProvider<S: Sendable>(_ provider: (any AirshipAI.ContextProvider<S>)?, for usage: AirshipAI.Usage<S>) {}
    func setDefaultContextProvider(_ provider: (any AirshipAI.ContextProvider<Void>)?) {}
    func setModelResolver(_ resolver: (@MainActor @Sendable (AirshipAI.AnyUsage) -> AirshipAI.ModelSelector)?) {}
    func evaluate<E: AirshipAI.Evaluation>(_ evaluation: E, additionalContext: AirshipAI.Context) async -> AirshipAI.Result<E.Output> { .skipped(reason: "preview") }
    func registerModelFactory(_ factory: @MainActor @Sendable @escaping () -> any AirshipAI.Model) {}
    func fetchContext<S: Sendable>(for usage: AirshipAI.Usage<S>, subject: S) async -> AirshipAI.Context { .empty }
}
