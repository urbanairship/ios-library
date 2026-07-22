/* Copyright Airship and Contributors */

import Foundation

/// Schedule-level AI suppression config (`ai_suppression`). When present, the SDK evaluates
/// `condition` against the current user context at prepare time and suppresses the schedule
/// when the AI decides the condition does not hold. Lives on the schedule, so it applies to
/// any automation type; each type builds its own AI usage/subject (in-app message for now).
struct AutomationAISuppression: Codable, Sendable, Equatable {
    /// The condition fragment injected into the SDK's instruction template — describes when
    /// the message should be shown (e.g. "user has not purchased in the last 30 days").
    let condition: String

    /// Extra key-value data passed to the app's context provider alongside the subject. Not
    /// included in the prompt or context by default — the app decides whether to use it.
    let subjectHints: [String: String]?

    /// What to do when the AI suppresses. Defaults to `.skip` (eligible again next trigger).
    let missBehavior: AutomationAudience.MissBehavior?

    enum CodingKeys: String, CodingKey {
        case condition
        case subjectHints = "subject_hints"
        case missBehavior = "miss_behavior"
    }
}
