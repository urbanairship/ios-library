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

    /// Expected output shape. When nil, the executor's default contract
    /// (`result` + `reason` strings) is used.
    var outputSchema: AirshipJSONSchema?

    enum CodingKeys: String, CodingKey {
        case prompt
        case outputSchema = "output_schema"
    }
}
