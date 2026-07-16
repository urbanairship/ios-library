/* Copyright Airship and Contributors */

import Foundation
public import AirshipBasement

/// A single on-device inference request over user-typed text.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasAIInferenceRequest: Sendable {
    /// Layout-authored instruction describing what to derive from the text.
    public let prompt: String

    /// The user's current text.
    public let text: String

    /// Expected output shape; nil falls back to the executor's default contract.
    public let outputSchema: AirshipJSONSchema?

    public init(
        prompt: String,
        text: String,
        outputSchema: AirshipJSONSchema? = nil
    ) {
        self.prompt = prompt
        self.text = text
        self.outputSchema = outputSchema
    }
}

/// Runs on-device AI inference for layout text inputs. The renderer is Core-free, so the
/// host supplies an implementation through `ThomasExtensions` (AirshipScenes wires one
/// backed by the SDK's AI manager).
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol ThomasAIInferenceExecutor: Sendable {

    /// Whether the on-device model can run right now. Callers check this before
    /// scheduling work so an absent model never delays the form — fail open, non-blocking.
    @MainActor
    var isAvailable: Bool { get }

    /// Runs inference over the user's text. Returns the model's structured output, or
    /// nil when the model is unavailable or the evaluation failed — callers fail open.
    func run(request: ThomasAIInferenceRequest) async -> AirshipJSON?
}
