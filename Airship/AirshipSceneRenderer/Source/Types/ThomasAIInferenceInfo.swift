/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// Layout-authored on-device AI inference config for a text input.
///
/// When present, the input's text is run through the on-device model as the user types
/// (debounced), and the structured output rides on the form field's result — projected
/// into the form state payload (`$forms.current.data.children.<id>.status.ai`) so
/// predicates and pager branching can react to it.
struct ThomasAIInferenceInfo: ThomasSerializable {
    /// Instruction describing what to derive from the user's text
    /// (e.g. "Classify the feedback as one of: shipping, quality, praise, other").
    var prompt: String

    /// Expected output shape for the inference.
    var outputSchema: AirshipJSONSchema

    /// Layout-authored context items appended to the prompt after any context the app's
    /// context provider returns. Lower-priority items are dropped first when the model's
    /// context window is tight.
    var additionalContext: [ContextItem]?

    /// Extra key-value data carried on the subject handed to the app's context provider
    /// (as `subject.hints`). Not added to the prompt by the renderer — the app decides
    /// whether and how to use it to shape the context it returns.
    var subjectHints: [String: String]?

    enum CodingKeys: String, CodingKey {
        case prompt
        case outputSchema = "output_schema"
        case additionalContext = "additional_context"
        case subjectHints = "subject_hints"
    }

    /// A single layout-authored context item. `content` is self-describing text
    /// (e.g. `"Favorite category: hiking"`) inserted into the prompt as-is.
    struct ContextItem: ThomasSerializable {
        var content: String

        /// Relative importance, where **lower is more important** (negatives allowed).
        /// The model drops the highest-valued items first when trimming context.
        /// Optional — defaults to `0` when omitted.
        var priority: Double?
    }
}
