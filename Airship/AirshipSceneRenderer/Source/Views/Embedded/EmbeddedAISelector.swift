/* Copyright Airship and Contributors */

import Foundation

/// A request to rank the pending embedded instances for AI-driven selection.
///
/// Separate from text-input inference (`SceneAIExecutor`): this is about choosing which
/// embedded content to display, not running inference inside a layout.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct EmbeddedAISelectionRequest: Sendable {

    /// The embedded ID being selected for.
    public let embeddedID: String

    /// Author-supplied instruction describing how to rank the candidates.
    public let prompt: String

    /// How AI scores and candidate priorities are combined to produce the final ordering.
    public let strategy: AirshipEmbeddedSelection.AIConfig.Strategy

    /// Minimum score the winning candidate must achieve for the result to be used.
    public let minScoreThreshold: Int?

    /// Author-supplied hints carried on the subject handed to the app's context provider.
    public let subjectHints: [String: String]

    /// The pending instances to rank. Also handed to the app's context provider (as
    /// `subject.pending`) so it can build context aware of what's being chosen between.
    public let candidates: [AirshipEmbeddedInfo]

    public init(
        embeddedID: String,
        prompt: String,
        strategy: AirshipEmbeddedSelection.AIConfig.Strategy = .scoreThenPriority,
        minScoreThreshold: Int? = nil,
        subjectHints: [String: String] = [:],
        candidates: [AirshipEmbeddedInfo]
    ) {
        self.embeddedID = embeddedID
        self.prompt = prompt
        self.strategy = strategy
        self.minScoreThreshold = minScoreThreshold
        self.subjectHints = subjectHints
        self.candidates = candidates
    }
}

/// Picks which pending embedded content to display via the on-device model.
///
/// Deliberately separate from `SceneAIExecutor` (text-input inference within a layout) — this is
/// an embedded-view concern. The renderer is Core-free, so AirshipScenes supplies the
/// implementation through `ThomasExtensions`.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol EmbeddedAISelector: Sendable {

    /// Whether the embedded-selection model can run right now. Callers check this before
    /// scheduling work so an absent model never blocks display — fail open.
    @MainActor
    var isAvailable: Bool { get }

    /// Ranks the candidates best-first. Returns candidate `instanceID`s in display order
    /// (deduped, real candidates only), or nil for no opinion (model unavailable/failed, or
    /// nothing usable) — the caller then applies its fallback selection.
    func rank(_ request: EmbeddedAISelectionRequest) async -> [String]?
}
