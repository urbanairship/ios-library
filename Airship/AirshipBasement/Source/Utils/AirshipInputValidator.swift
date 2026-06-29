/* Copyright Airship and Contributors */

import Foundation
import Combine

/// A struct that encapsulates input validation logic for different request types such as email and SMS.
public struct AirshipInputValidation {

    /// A closure type used for overriding validation logic.
    public typealias OverridesClosure = (@Sendable (Request) async throws -> Override)

    private init() {}

    /// Enum representing the result of validation.
    /// It indicates whether an input is valid or invalid.
    public enum Result: Sendable, Equatable {
        /// Indicates a valid input with the associated address (e.g., email or phone number).
        case valid(address: String)
        /// Indicates an invalid input.
        case invalid
    }

    /// Enum representing the override options for input validation.
    public enum Override: Sendable, Equatable {
        /// Override the result of validation with a custom validation result.
        case override(Result)
        /// Skip the override and use the default validation method.
        case useDefault
    }

    /// Enum representing the types of requests to be validated (e.g., Email or SMS).
    public enum Request: Sendable, Equatable {
        case email(Email)
        case sms(SMS)

        /// A struct representing an SMS request for validation.
        public struct SMS: Sendable, Equatable {
            public var rawInput: String
            public var validationOptions: ValidationOptions
            public var validationHints: ValidationHints?

            /// Enum specifying the options for validating an SMS, such as sender ID or prefix.
            public enum ValidationOptions: Sendable, Equatable {
                case sender(senderID: String, prefix: String? = nil)
                case prefix(prefix: String)
            }

            /// A struct for defining validation hints like min/max digit requirements.
            public struct ValidationHints: Sendable, Equatable {
                public var minDigits: Int?
                public var maxDigits: Int?

                public init(minDigits: Int? = nil, maxDigits: Int? = nil) {
                    self.minDigits = minDigits
                    self.maxDigits = maxDigits
                }
            }

            /// Initializes the SMS validation request.
            /// - Parameters:
            ///   - rawInput: The raw input string to be validated.
            ///   - validationOptions: The validation options to be applied.
            ///   - validationHints: Optional validation hints such as min/max digit constraints.
            public init(
                rawInput: String,
                validationOptions: ValidationOptions,
                validationHints: ValidationHints? = nil
            ) {
                self.rawInput = rawInput
                self.validationOptions = validationOptions
                self.validationHints = validationHints
            }
        }

        /// A struct representing an email request for validation.
        public struct Email: Sendable, Equatable {
            public var rawInput: String

            /// Initializes the Email validation request.
            /// - Parameter rawInput: The raw email input to be validated.
            public init(rawInput: String) {
                self.rawInput = rawInput
            }
        }
    }

    /// Protocol for validators that perform validation of input requests.
    /// - Note: For internal use only. :nodoc:
    public protocol Validator: AnyObject, Sendable {
        /// Validates the provided request and returns a result.
        /// - Parameter request: The request to be validated (either SMS or Email).
        /// - Throws: Can throw errors if validation fails.
        /// - Returns: The validation result, either valid or invalid.
        func validateRequest(_ request: Request) async throws -> Result
    }
}
