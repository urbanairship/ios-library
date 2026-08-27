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

private extension AirshipEmbeddedInfo {
    /// Whether this candidate carries anything that could set it apart from the others. An
    /// instance ID alone is not something to reason about — it's a UUID.
    ///
    /// `additionalContext` deliberately doesn't count: it's pooled into the shared context,
    /// so it's background for the whole decision and identical for every candidate. Only
    /// what stays on the candidate can differentiate it.
    var isDescribable: Bool {
        contentDescription?.isEmpty == false || extras != nil
    }
}

@_spi(AirshipInternal)
public extension EmbeddedAISelectionRequest {
    /// The candidates' authored `content_description.additional_context`, folded into one
    /// context the manager appends after the app provider's.
    ///
    /// Pooled rather than attached per candidate so every context item — app-supplied or
    /// layout-supplied — renders in one section and rides the same trimmed channel, which
    /// is what makes the authored `priority` mean something. The trade is attribution: an
    /// item reads as background for the whole decision, not as a fact about the one
    /// candidate that declared it.
    ///
    /// Deduped by content because sibling layouts in a campaign routinely repeat a line;
    /// a repeat keeps its most important (lowest) priority and its first-seen position.
    var layoutContext: AirshipAI.Context {
        var order: [String] = []
        var priorities: [String: Double] = [:]

        for item in candidates.flatMap(\.additionalContext) where !item.content.isEmpty {
            if let existing = priorities[item.content] {
                priorities[item.content] = min(existing, item.priority)
            } else {
                priorities[item.content] = item.priority
                order.append(item.content)
            }
        }

        return AirshipAI.Context(
            items: order.map { .init(content: $0, priority: priorities[$0] ?? 0) }
        )
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

        // All-or-nothing, never per-candidate: if even one candidate is describable the model
        // runs and every candidate goes into the prompt, however thin. Only when NOTHING is
        // describable is the run skipped — with bare UUIDs the instructions say score
        // everything 5, which is the fallback's own ordering, so the round-trip buys nothing
        // and the caller shows a placeholder through it.
        //
        // Note this is not a filter: a candidate the model declines to score still lands in
        // the ranking, at the end and in priority order — see `unscored` below.
        guard request.candidates.contains(where: \.isDescribable) else {
            AirshipLogger.debug("Embedded AI selection has nothing to rank on, using fallback")
            return nil
        }

        let result = await aiManager.evaluate(
            EmbeddedSelectionEvaluation(request: request),
            additionalContext: request.layoutContext
        )

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

    // `requiresContext` stays at the protocol default (false): the author's prompt and the
    // candidates' `content_description` can carry a ranking on their own, so demanding an
    // app-registered context provider would block selection for apps that don't need one.
    // `DefaultEmbeddedAISelector.rank` applies the narrower guard that actually matters —
    // that the candidates are distinguishable at all.

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
        1. Read the "User context" section, if there is one, for facts about the user \
        (interests, history, how they were targeted). That section is the only evidence about \
        the user, and it applies to the decision as a whole rather than to any one candidate. \
        There may be no user context at all; that is normal, and the instruction above may be \
        all you need to rank on.
        2. Carefully read each candidate's `description` and any `extras` it carries — those \
        describe that one candidate, and they are the content being scored. Never read a \
        candidate's own text as evidence about the user.
        3. Give every candidate a score from 1 to 10 for how well it matches the instruction \
        and the user context. Return exactly one score per candidate id; never omit or invent an id.

        Scoring Rules:
        - 9–10: Direct match to a stated user interest or the instruction.
        - 6–8: Plausibly relevant or broadly applicable.
        - 1–4: Mismatch or a competing item (e.g., dog items when the user likes cats).
        - Score every candidate exactly 5 only when NEITHER the instruction NOR the user \
        context gives you any basis to tell the candidates apart. Missing user context on its \
        own is not such a case: if the instruction alone ranks them, rank them.

        Important: Match each candidate's description to its correct id.
        """
    }

    public func prompt(context: AirshipAI.Context) -> String {
        var parts: [String] = []

        let candidateObjects = request.candidates.map { candidate -> AirshipJSON in
            // Extras are nested rather than flattened: they're author-supplied, so a key
            // like `id` would otherwise collide with the instance ID that scores are
            // matched back by, silently dropping the candidate from the ranking.
            var dict: [String: AirshipJSON] = ["id": .string(candidate.instanceID)]
            if let description = candidate.contentDescription {
                dict["description"] = .string(description)
            }
            // `additional_context` is deliberately NOT here: it's pooled into the shared
            // context (see `EmbeddedAISelectionRequest.layoutContext`) so every context item
            // renders in one section and can be trimmed by priority. A candidate carries only
            // what identifies it — its description and its extras.
            if let extras = candidate.extras {
                dict["extras"] = extras
            }
            return .object(dict)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let candidateBlock = (try? AirshipJSON.array(candidateObjects).toString(encoder: encoder)) ?? "[]"
        parts.append("Score each of the following candidates according to the system instructions.\n\nCandidates:\n\(candidateBlock)")

        // One section for every context item, whatever supplied it — the app's provider and
        // the layouts' `additional_context` render identically and are indistinguishable to
        // the model by design. Both are expected to be user-framed facts.
        if let bullets = context.renderBullets() {
            parts.append("User context:\n\(bullets)")
        }

        return parts.joined(separator: "\n\n")
    }
}
