/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) public import AirshipSceneRenderer
@_spi(AirshipInternal) public import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

extension AirshipAI {
    /// Namespace for the embedded-view AI selection usage.
    public enum EmbeddedSelection {
        /// The AI usage key for embedded-view selection.
        ///
        /// Pass this to `Airship.ai.setContextProvider(_:for:)` to register a context provider.
        public static let usage = AirshipAI.Usage<Subject>(rawValue: "embedded_selection")

        /// The context subject handed to the app's registered context provider so it can build
        /// relevant `Context` for the selection (e.g. user preferences). Carries the layout's
        /// `hints` (`subject_hints`).
        public struct Subject: Sendable {
            /// The embedded ID being selected for.
            public let embeddedID: String

            /// The pending embedded instances being ranked — the set the model is choosing between.
            /// A context provider can inspect these to build relevant context.
            public let pending: [AirshipEmbeddedInfo]

            /// Layout-authored `subject_hints`. Empty when the layout provides none.
            public let hints: [String: String]

            public init(embeddedID: String = "", pending: [AirshipEmbeddedInfo] = [], hints: [String: String] = [:]) {
                self.embeddedID = embeddedID
                self.pending = pending
                self.hints = hints
            }
        }
    }
}

/// Ranks pending embedded instances with the on-device model. Wired into the renderer via
/// `DefaultThomasExtensions` when the host has an AI manager. Its own usage
/// (`embedded_selection`) — independent of text-input inference.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct DefaultEmbeddedAISelector: EmbeddedAISelector {

    private let aiManager: any AirshipAI.InternalManager

    public init(aiManager: any AirshipAI.InternalManager) {
        self.aiManager = aiManager
    }

    @MainActor
    public var isAvailable: Bool {
        aiManager.model(for: AirshipAI.EmbeddedSelection.usage)?.availability == .available
    }

    public func rank(_ request: EmbeddedAISelectionRequest) async -> [String]? {
        guard !request.candidates.isEmpty else { return nil }

        let result = await aiManager.evaluate(EmbeddedSelectionEvaluation(request: request))

        switch result {
        case .completed(let output):
            let priorityByID = Dictionary(
                uniqueKeysWithValues: request.candidates.map { ($0.instanceID, $0.priority) }
            )
            let known = Set(request.candidates.map(\.instanceID))
            var seen = Set<String>()
            let ordered = output.scores
                .filter { known.contains($0.id) && seen.insert($0.id).inserted }
                .sorted { lhs, rhs in
                    let lp = priorityByID[lhs.id] ?? .max
                    let rp = priorityByID[rhs.id] ?? .max
                    switch request.strategy {
                    case .scoreThenPriority:
                        if lhs.score != rhs.score { return lhs.score > rhs.score }
                        return lp < rp
                    case .priorityThenScore:
                        if lp != rp { return lp < rp }
                        return lhs.score > rhs.score
                    @unknown default:
                        if lhs.score != rhs.score { return lhs.score > rhs.score }
                        return lp < rp
                    }
                }
                .map(\.id)
            let unscored = request.candidates
                .filter { !seen.contains($0.instanceID) }
                .sorted { $0.priority < $1.priority }
                .map(\.instanceID)
            let ranking = ordered + unscored
            guard !ranking.isEmpty else {
                AirshipLogger.warn("Embedded AI selection returned no scored ids")
                return nil
            }
            if let threshold = request.minScoreThreshold {
                let topScore = output.scores.first(where: { $0.id == ranking[0] })?.score ?? 0
                guard topScore >= threshold else {
                    AirshipLogger.debug("Embedded AI top score \(topScore) below threshold \(threshold), using fallback")
                    return nil
                }
            }
            AirshipLogger.debug("Embedded AI ranking \(ranking): \(output.reason)")
            return ranking
        case .skipped(let reason):
            AirshipLogger.debug("Embedded AI selection skipped: \(reason)")
            return nil
        case .failed(let error):
            AirshipLogger.warn("Embedded AI selection failed: \(error)")
            return nil
        @unknown default:
            return nil
        }
    }
}

@_spi(AirshipInternal)
public struct EmbeddedSelectionEvaluation: AirshipAI.Evaluation {
    public struct Output: Decodable, Sendable {
        public struct CandidateScore: Decodable, Sendable {
            public let id: String
            public let score: Int
        }
        public let scores: [CandidateScore]
        public let reason: String
    }

    public typealias Subject = AirshipAI.EmbeddedSelection.Subject

    public let request: EmbeddedAISelectionRequest

    public init(request: EmbeddedAISelectionRequest) {
        self.request = request
    }

    public let usage: AirshipAI.Usage<AirshipAI.EmbeddedSelection.Subject> = AirshipAI.EmbeddedSelection.usage

    public var subject: AirshipAI.EmbeddedSelection.Subject {
        AirshipAI.EmbeddedSelection.Subject(embeddedID: request.embeddedID, pending: request.candidates, hints: request.subjectHints)
    }

    public var schema: AirshipJSONSchema {
        AirshipJSONSchema.object(
            properties: [
                "scores": .array(
                    items: .object(
                        properties: [
                            "id": .string(choices: request.candidates.map(\.instanceID)),
                            "score": .integer(description: "Relevance score 1–10, higher is a better match"),
                        ],
                        required: ["id", "score"]
                    ),
                    description: "A relevance score for each candidate"
                ),
                "reason": .string(description: "Brief reason for the scores"),
            ],
            required: ["scores", "reason"]
        )
    }

    public func instructions() -> String {
        """
        You are scoring content candidates for a user based on a prompt and context.

        Instruction:
        <prompt>\(request.prompt)</prompt>

        Steps:
        1. Check background context for facts needed by the instruction (e.g., user interests or history).
        2. Carefully read each candidate's description text.
        3. Assign a score from 1 to 10 based on how well the candidate matches the instruction and context.

        Scoring Rules:
        - 9–10: Direct match (e.g., cat items for a cat interest).
        - 5–8: Generic, broadly applicable, or fallback score if no relevant context exists.
        - 1–4: Mismatch or competing item (e.g., dog items when context specifies cats).

        Important: Ensure you match each candidate's description to its correct ID.
        """
    }

    public func prompt(context: AirshipAI.Context) -> String {
        var parts: [String] = []

        let candidateObjects = request.candidates.map { candidate -> AirshipJSON in
            var dict: [String: AirshipJSON] = ["id": .string(candidate.instanceID)]
            if let extras = candidate.extras, case .object(let extrasDict) = extras {
                dict.merge(extrasDict) { _, new in new }
            }
            return .object(dict)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let candidateBlock = (try? AirshipJSON.array(candidateObjects).toString(encoder: encoder)) ?? "[]"
        parts.append("Score each of the following candidates according to the system instructions.\n\nCandidates:\n\(candidateBlock)")

        if let bullets = context.renderBullets() {
            parts.append("User context:\n\(bullets)")
        }

        return parts.joined(separator: "\n\n")
    }
}
