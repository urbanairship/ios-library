/* Copyright Airship and Contributors */

import Foundation
public import AirshipBasement

/// A single layout-authored context item for an inference request. Renderer-side mirror
/// of the AI framework's context item, kept Core-free so it can live in the renderer.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasAIContextItem: Sendable {
    /// Self-describing text inserted into the prompt as-is.
    public let content: String

    /// Drop-ordering priority, where **lower is more important** (negatives allowed,
    /// ranking above the `0` default). Items with the highest value are dropped first
    /// when the model trims context to fit its input budget.
    public let priority: Double

    public init(content: String, priority: Double = 0.0) {
        self.content = content
        self.priority = priority
    }
}

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

    /// Layout-authored context appended after the app's provider context.
    public let additionalContext: [ThomasAIContextItem]

    /// Layout-authored hints carried on the subject handed to the app's context provider
    /// (as `subject.hints`).
    public let subjectHints: [String: String]

    public init(
        prompt: String,
        text: String,
        outputSchema: AirshipJSONSchema? = nil,
        additionalContext: [ThomasAIContextItem] = [],
        subjectHints: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.text = text
        self.outputSchema = outputSchema
        self.additionalContext = additionalContext
        self.subjectHints = subjectHints
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

    /// A stream of availability changes, starting with the current value and emitting
    /// whenever it changes. Thomas bridges this to a Combine publisher to project
    /// `$ai.available` into layout state for predicates and pager branching.
    @MainActor
    var availabilityUpdates: AsyncStream<Bool> { get }

    /// Runs inference over the user's text. Returns the model's structured output, or
    /// nil when the model is unavailable or the evaluation failed — callers fail open.
    func run(request: ThomasAIInferenceRequest) async -> AirshipJSON?
}
