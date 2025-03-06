/* Copyright Airship and Contributors */

import Foundation

/// Represents the possible statuses of a form during its lifecycle.
enum ThomasFormStatus: Encodable, Equatable, Sendable {
    /// The form is valid and all its fields are correctly filled out.
    case valid

    /// The form is invalid, possibly due to incorrect or missing information.
    case invalid(ChildValidationResults)

    /// An error occurred during form validation or submission.
    case error(ChildValidationResults)

    /// The form is currently being validated.
    case validating

    /// The form is awaiting validation to be processed.
    case pendingValidation

    /// The form has been submitted.
    case submitted

    enum CodingKeys: String, CodingKey {
        case type
        case childValidationResults = "children"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        switch(self) {
        case .valid:
            try container.encode("valid", forKey: .type)

        case .invalid(let children):
            try container.encode("invalid", forKey: .type)
            try container.encode(children, forKey: .childValidationResults)

        case .error(let children):
            try container.encode("error", forKey: .type)
            try container.encode(children, forKey: .childValidationResults)

        case .validating:
            try container.encode("validating", forKey: .type)

        case .pendingValidation:
            try container.encode("pending_validation", forKey: .type)

        case .submitted:
            try container.encode("submitted", forKey: .type)
        }
    }

    /// Validation results for `error` or `invalid` status.
    /// This structure holds validation status information for the child elements of the form.
    struct ChildValidationResults: Encodable, Equatable, Sendable {

        /// A dictionary where each key is a child form field ID, and the value represents
        /// the validation status of that field.
        var status: [String: ChildValidationStatus]
    }

    /// Represents the validation status of an individual child field within the form.
    /// These statuses are used to communicate the current validation state of each form field.
    enum ChildValidationStatus: String, Encodable, Equatable, Sendable {

        /// The field is valid and passes all validation checks.
        case valid

        /// The field is invalid due to errors or missing information.
        case invalid

        /// The field is awaiting validation, meaning it's in a pending state.
        case pendingValidation = "pending_validation"

        /// An error occurred while validating the field.
        case error
    }

    var isError: Bool {
        return switch(self) {
        case .error: true
        default: false
        }
    }
}
