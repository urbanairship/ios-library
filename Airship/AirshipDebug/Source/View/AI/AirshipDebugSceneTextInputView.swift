/* Copyright Airship and Contributors */

import Combine
import SwiftUI
@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement
@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipScenes

/// Debug sandbox for the scene text-input AI usage (`scene_text_input`).
///
/// Drives the real ``DefaultThomasAIInferenceExecutor`` — the same path a scene text
/// input uses — so you can author a prompt + output schema, type sample text, and see the
/// structured output and the form-state `ai` payload predicates/branching would read.
struct AirshipDebugSceneTextInputView: View {
    @StateObject private var viewModel: ViewModel
    @FocusState private var keyboardActive: Bool

    init(manager: any AirshipAI.InternalManager) {
        _viewModel = StateObject(wrappedValue: ViewModel(manager: manager))
    }

    var body: some View {
        List {
            Section {
#if os(tvOS)
                TextField("e.g. Classify the feedback as one of: shipping, quality, praise, other", text: $viewModel.prompt)
                    .focused($keyboardActive)
#else
                TextEditor(text: $viewModel.prompt)
                    .focused($keyboardActive)
                    .frame(minHeight: 72)
                    .overlay(alignment: .topLeading) {
                        if viewModel.prompt.isEmpty {
                            Text("e.g. Classify the feedback as one of: shipping, quality, praise, other")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
#endif
            } header: {
                Text("Instruction Prompt")
            }

            Section("Input") {
#if os(tvOS)
                TextField("User text to run inference over…", text: $viewModel.userText)
                    .focused($keyboardActive)
#else
                TextEditor(text: $viewModel.userText)
                    .focused($keyboardActive)
                    .frame(minHeight: 72)
                    .overlay(alignment: .topLeading) {
                        if viewModel.userText.isEmpty {
                            Text("User text to run inference over…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
#endif
            }

            schemaSection

            Section {
                Button {
                    keyboardActive = false
                    Task { await viewModel.run() }
                } label: {
                    HStack {
                        Spacer()
                        Text("Run inference").bold()
                        Spacer()
                    }
                }
                .disabled(viewModel.isRunning || viewModel.userText.isEmpty)
            }

            resultSection
            contextSection
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
        .navigationTitle("Scene Text Input")
        .onAppear { Task { await viewModel.fetchContext() } }
    }

    @ViewBuilder
    private var schemaSection: some View {
        Section {
            Toggle("Custom output schema", isOn: $viewModel.useCustomSchema)

            Button {
                keyboardActive = false
                Task { await viewModel.generateSchema() }
            } label: {
                if viewModel.isGeneratingSchema {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Generating…").foregroundStyle(.secondary)
                    }
                } else {
                    Label("Generate from prompt", systemImage: "sparkles")
                }
            }
            .disabled(viewModel.prompt.isEmpty || viewModel.isGeneratingSchema || viewModel.availability != .available)

            if let error = viewModel.schemaGenError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if viewModel.useCustomSchema {
                NavigationLink {
                    SchemaNodeEditorView(node: viewModel.schemaRoot, title: "Output Schema")
                } label: {
                    HStack {
                        Text("Edit schema")
                        Spacer()
                        Text(viewModel.schemaRoot.typeSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Using default contract: { result, reason }")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Output Schema")
        } footer: {
            if viewModel.useCustomSchema {
                Text(viewModel.schemaJSONPreview)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        Section("Result") {
            if viewModel.isRunning {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Running…").foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                switch viewModel.result {
                case .none:
                    Text("Not run yet").foregroundStyle(.secondary)
                case .output(let raw, let projected):
                    VStack(alignment: .leading, spacing: 8) {
                        labeledJSON("Model output", raw)
                        labeledJSON("Projected form-state `ai` payload", projected)
                    }
                case .noOutput:
                    Label(
                        "No output — model unavailable or evaluation failed (see Model Status). Scenes fail open here.",
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var contextSection: some View {
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
                Text("No context provided")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func labeledJSON(_ label: String, _ json: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(json)
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

// MARK: - ViewModel

extension AirshipDebugSceneTextInputView {

    enum RunResult {
        case output(raw: String, projected: String)
        case noOutput
    }

    @MainActor
    final class ViewModel: ObservableObject {
        @Published var prompt: String = ""
        @Published var userText: String = ""
        @Published var useCustomSchema: Bool = false
        @Published var context: AirshipAI.Context?
        @Published var isFetchingContext = false
        @Published var isRunning = false
        @Published var result: RunResult?
        @Published var availability: AirshipAI.Availability = .unavailable(reason: .missingModel)
        @Published var isGeneratingSchema = false
        @Published var schemaGenError: String?

        let schemaRoot = SchemaNodeModel.defaultContract()

        private let manager: any AirshipAI.InternalManager
        private let executor: DefaultThomasAIInferenceExecutor

        init(manager: any AirshipAI.InternalManager) {
            self.manager = manager
            self.executor = DefaultThomasAIInferenceExecutor(aiManager: manager)
        }

        var availabilityLabel: String {
            switch availability {
            case .available: return "Available"
            case .unavailable(let reason): return "Unavailable (\(reason))"
            @unknown default: return "Unknown"
            }
        }

        var schemaJSONPreview: String {
            Self.prettyString(from: schemaRoot.build()) ?? "(invalid schema)"
        }

        func fetchContext() async {
            availability = manager.availability
            isFetchingContext = true
            defer { isFetchingContext = false }
            context = await manager.fetchContext(
                for: SceneTextInputInferenceSubject.inferenceUsage,
                subject: SceneTextInputInferenceSubject()
            )
        }

        /// Asks the on-device model (same Airship AI stack as inference, just a different
        /// evaluation) to design the output schema for the current instruction prompt, then
        /// drops the suggested fields into the builder.
        func generateSchema() async {
            let instruction = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !instruction.isEmpty else { return }

            isGeneratingSchema = true
            schemaGenError = nil
            defer { isGeneratingSchema = false }

            availability = manager.availability

            switch await manager.evaluate(SchemaSuggestionEvaluation(instruction: instruction)) {
            case .completed(let output):
                applySuggestion(output)
                useCustomSchema = true
            case .skipped(let reason):
                schemaGenError = "Skipped: \(reason)"
            case .failed(let error):
                schemaGenError = "Failed: \(error.localizedDescription)"
            @unknown default:
                schemaGenError = "Unexpected result"
            }
        }

        private func applySuggestion(_ output: SchemaSuggestionEvaluation.Output) {
            let properties = output.properties.map { field -> SchemaNodeModel.Property in
                // Choices present ⇒ a string enum, regardless of how the model labeled
                // `type` (JSON Schema has no "enum" type — enum is a constraint on a
                // string), so this catches `type: "string"` with an `enum` array too.
                let kind: SchemaNodeModel.Kind
                if !(field.choices ?? []).isEmpty {
                    kind = .stringEnum
                } else {
                    switch field.type.lowercased() {
                    case "enum": kind = .stringEnum
                    case "boolean", "bool": kind = .boolean
                    case "integer", "int": kind = .integer
                    case "number", "double", "float": kind = .number
                    default: kind = .string
                    }
                }
                let node = SchemaNodeModel(
                    kind: kind,
                    descriptionText: field.description ?? "",
                    choicesText: (field.choices ?? []).joined(separator: ", ")
                )
                return SchemaNodeModel.Property(
                    name: field.name,
                    required: field.required ?? false,
                    node: node
                )
            }
            schemaRoot.applyObject(properties: properties)
        }

        func run() async {
            isRunning = true
            result = nil
            defer { isRunning = false }

            availability = manager.availability
            await fetchContext()

            let request = ThomasAIInferenceRequest(
                prompt: prompt,
                text: userText,
                outputSchema: useCustomSchema ? schemaRoot.build() : nil
            )

            guard let output = await executor.run(request: request) else {
                result = .noOutput
                return
            }

            result = .output(
                raw: Self.prettyString(from: output) ?? "\(output)",
                projected: Self.prettyString(from: Self.projected(output)) ?? "{}"
            )
        }

        /// Mirrors `TextInput`'s projection: object outputs are flattened next to
        /// `status`; scalar/array outputs land under `result`.
        private static func projected(_ output: AirshipJSON) -> AirshipJSON {
            var ai: [String: AirshipJSON] = output.object ?? ["result": output]
            ai["status"] = .string("complete")
            return .object(ai)
        }

        private static func prettyString<T: Encodable>(from value: T) -> String? {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            guard
                let data = try? encoder.encode(value),
                let string = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return string
        }
    }
}

// MARK: - Schema suggestion evaluation

/// No context needed for schema design.
private struct SchemaSuggestionSubject: Sendable {}

/// Runs on the same on-device Airship AI stack as text-input inference, but asks the model
/// to design the *output shape* for an instruction rather than to classify text. Kept flat
/// (a list of leaf fields) so guided generation stays reliable — nesting is left to the
/// manual builder.
private struct SchemaSuggestionEvaluation: AirshipAI.Evaluation {

    struct Field: Decodable, Sendable {
        let name: String
        let type: String
        let choices: [String]?
        let description: String?
        let required: Bool?

        enum CodingKeys: String, CodingKey {
            case name, type, description, required
            case choices = "enum"
        }
    }

    struct Output: Decodable, Sendable {
        let properties: [Field]
    }

    let instruction: String

    let usage = AirshipAI.Usage<SchemaSuggestionSubject>(rawValue: "debug_schema_suggestion")
    let subject = SchemaSuggestionSubject()

    let schema = AirshipJSONSchema.object(
        properties: [
            "properties": .array(
                items: .object(
                    properties: [
                        "name": .string(description: "Field name in snake_case"),
                        "type": .string(
                            choices: ["string", "boolean", "integer", "number"],
                            description: "The field's JSON value type"
                        ),
                        "enum": .array(
                            items: .string(),
                            description: "For a string field limited to a fixed set of values, list every allowed value here"
                        ),
                        "description": .string(description: "What this field captures"),
                        "required": .boolean(description: "Whether the field is always present"),
                    ],
                    required: ["name", "type"]
                ),
                description: "The fields the model's output object should contain"
            )
        ],
        required: ["properties"]
    )

    func instructions() -> String {
        """
        You design the JSON output shape an on-device model should return for a form \
        text-input task. Given the author's instruction, list the fields the output object \
        should contain. Prefer a small, flat set.

        When the instruction names a fixed set of categories or options (e.g. "categorize \
        into happy, sad, or mad"), add a string field whose `enum` lists exactly those \
        values — do not leave it as an unconstrained string. Always also include a short \
        free-text field (e.g. "reason") explaining the result.
        """
    }

    func prompt() -> String {
        "Instruction: \(instruction)"
    }
}
