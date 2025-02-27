/* Copyright Airship and Contributors */

import Foundation

/// Represents the possible statuses of a form during its lifecycle.
enum ThomasFormStatus: String, Equatable, Decodable, Sendable {
    /// The form is valid and all its fields are correctly filled out.
    case valid

    /// The form is invalid, possibly due to incorrect or missing information.
    case invalid

    /// An error occurred during form validation or submission.
    case error

    /// The form is currently being validated.
    case validating

    /// The form is awaiting validation to be processed.
    case pendingValidation = "pending_validation"

    /// The form has been submitted.
    case submitted
}
