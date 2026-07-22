/* Copyright Airship and Contributors */

@_spi(AirshipInternal) public import AirshipSceneRenderer
@_spi(AirshipInternal) public import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

/// The context subject for scene text-input AI inference.
///
/// Handed to the app's registered context provider so it can build relevant `Context` for
/// the evaluation. Carries the user's current `text` and the layout's `hints`
/// (`subject_hints`). The renderer adds the text to the prompt itself; neither field is a
/// substitute for the context the provider returns.
public struct SceneTextInputInferenceSubject: Sendable {
    /// The AI usage key for scene text-input inference.
    ///
    /// Pass this to `Airship.ai.setProvider(_:for:)` when registering a context provider
    /// for scene text-input inference.
    public static let inferenceUsage = AirshipAI.Usage<SceneTextInputInferenceSubject>(
        rawValue: "scene_text_input"
    )

    /// The user's current text for the field being evaluated. Empty when unavailable.
    public let text: String

    /// Layout-authored `subject_hints`. Empty when the layout provides none.
    public let hints: [String: String]

    public init(text: String = "", hints: [String: String] = [:]) {
        self.text = text
        self.hints = hints
    }
}

/// Runs scene text-input inference through the injected AI manager. Wired into the
/// renderer via `DefaultThomasExtensions` when the host has an AI manager to give it.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct DefaultThomasAIInferenceExecutor: ThomasAIInferenceExecutor {

    private let aiManager: any AirshipAI.InternalManager

    public init(aiManager: any AirshipAI.InternalManager) {
        self.aiManager = aiManager
    }

    public var isAvailable: Bool {
        aiManager.availability == .available
    }

    @MainActor
    public var availabilityUpdates: AsyncStream<Bool> {
        let stream = aiManager.availabilityUpdates
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                for await availability in stream {
                    continuation.yield(availability == .available)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func run(request: ThomasAIInferenceRequest) async -> AirshipJSON? {
        let result = await aiManager.evaluate(
            ThomasAIInferenceEvaluation(request: request)
        )

        switch result {
        case .completed(let output):
            return output
        case .skipped(let reason):
            AirshipLogger.debug("Scene AI inference skipped: \(reason)")
            return nil
        case .failed(let error):
            AirshipLogger.warn("Scene AI inference failed: \(error)")
            return nil
        @unknown default:
            return nil
        }
    }
}

struct ThomasAIInferenceEvaluation: AirshipAI.Evaluation {
    // The output shape is layout-defined, so the raw JSON is the output — the scene
    // writes it into layout state as-is rather than decoding a fixed type.
    typealias Output = AirshipJSON
    typealias Subject = SceneTextInputInferenceSubject

    /// The contract used when the layout doesn't define an `output_schema`.
    static let defaultSchema = AirshipJSONSchema.object(
        properties: [
            "result": .string(description: "The value the instruction asks for"),
            "reason": .string(description: "Brief reason for the result"),
        ],
        required: ["result", "reason"]
    )

    let request: ThomasAIInferenceRequest

    let usage: AirshipAI.Usage<SceneTextInputInferenceSubject> = SceneTextInputInferenceSubject.inferenceUsage

    var subject: SceneTextInputInferenceSubject {
        SceneTextInputInferenceSubject(text: request.text, hints: request.subjectHints)
    }

    var schema: AirshipJSONSchema {
        request.outputSchema ?? Self.defaultSchema
    }

    /// Layout-authored context, appended after the provider's context by the framework.
    var additionalContext: AirshipAI.Context {
        AirshipAI.Context(
            items: request.additionalContext.map { item in
                AirshipAI.Context.Item(content: item.content, priority: item.priority)
            }
        )
    }

    func instructions() -> String {
        """
        You derive structured data from text a user typed into a form field inside an \
        in-app experience. Apply this instruction to the user's text:

        \(request.prompt)

        Base the output only on the user's text and any user context given in the \
        prompt. If the text is genuinely insufficient to judge, choose the most \
        neutral output the instruction allows.
        """
    }

    func prompt() -> String {
        // Only the user's text is the subject. Provider context is fetched by the
        // framework and appended by the model, which may trim low-priority items.
        "User text: \(request.text)"
    }
}
