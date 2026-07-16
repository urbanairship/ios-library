/* Copyright Airship and Contributors */

@_spi(AirshipInternal) public import AirshipSceneRenderer
@_spi(AirshipInternal) public import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

/// The context subject for scene text-input AI inference.
///
/// Carries no fields: the user's text rides the evaluation `prompt()` and user context
/// comes from the app's provider, so there is nothing input-specific to hand the provider.
/// It exists only to give the `scene_text_input` usage a distinct typed provider slot.
public struct ThomasTextInputInferenceSubject: Sendable {
    /// The AI usage key for scene text-input inference.
    ///
    /// Pass this to `Airship.ai.setProvider(_:for:)` when registering a context provider
    /// for scene text-input inference.
    public static let inferenceUsage = AirshipAI.Usage<ThomasTextInputInferenceSubject>(
        rawValue: "scene_text_input"
    )

    public init() {}
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
    typealias Subject = ThomasTextInputInferenceSubject

    /// The contract used when the layout doesn't define an `output_schema`.
    static let defaultSchema = AirshipJSONSchema.object(
        properties: [
            "result": .string(description: "The value the instruction asks for"),
            "reason": .string(description: "Brief reason for the result"),
        ],
        required: ["result", "reason"]
    )

    let request: ThomasAIInferenceRequest

    let usage: AirshipAI.Usage<ThomasTextInputInferenceSubject> = ThomasTextInputInferenceSubject.inferenceUsage

    let subject = ThomasTextInputInferenceSubject()

    var schema: AirshipJSONSchema {
        request.outputSchema ?? Self.defaultSchema
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
