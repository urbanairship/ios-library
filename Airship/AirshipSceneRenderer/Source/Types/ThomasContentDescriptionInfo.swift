/* Copyright Airship and Contributors */

import Foundation

/// Layout-authored description of what the content is about (`content_description`).
///
/// Unlike a view's accessibility label, this describes the *message* for machine consumers
/// rather than for a screen reader — today, the on-device model that ranks pending embedded
/// instances for `.ai` selection. It lives on the layout root so a scene carries one
/// description no matter how many views it renders.
struct ThomasContentDescriptionInfo: ThomasSerializable {
    /// A short, self-describing summary of the content
    /// (e.g. "Spring sale on cat trees, toys, and grooming supplies").
    var description: String?

    /// Layout-authored user context — facts about the person this content was composed for
    /// (interests, how they were targeted) that the app's own context provider can't know.
    ///
    /// Merged with the app provider's context rather than attached to this layout, exactly
    /// as `ai_inference.additional_context` is for text inputs: one pooled context, rendered
    /// in one section, trimmed by `priority` when the model's input budget is tight. Write
    /// facts about the *user* here; what the content itself is goes in `description`.
    var additionalContext: [ThomasAIContextItemInfo]?

    enum CodingKeys: String, CodingKey {
        case description
        case additionalContext = "additional_context"
    }
}
