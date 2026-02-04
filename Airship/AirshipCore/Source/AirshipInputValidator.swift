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
                var minDigits: Int?
                var maxDigits: Int?

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
    /// NOTE: For internal use only. :nodoc:
    public protocol Validator: AnyObject, Sendable {
        /// Validates the provided request and returns a result.
        /// - Parameter request: The request to be validated (either SMS or Email).
        /// - Throws: Can throw errors if validation fails.
        /// - Returns: The validation result, either valid or invalid.
        func validateRequest(_ request: Request) async throws -> Result
    }
}

extension AirshipInputValidation {
    /// A default implementation of the `Validator` protocol that uses a standard SMS validation API.
    /// /// NOTE: For internal use only. :nodoc:
    final class DefaultValidator: Validator {

        // Regular expression for validating email addresses.
        private static let emailRegex: String = #"^[^@\s]+@[^@\s]+\.[^@\s.]+$"#

        private let overrides: OverridesClosure?
        private let smsValidatorAPIClient: any SMSValidatorAPIClientProtocol

        /// Initializes the validator with custom overrides and a SMS validation API client.
        /// - Parameters:
        ///   - smsValidatorAPIClient: The client used to validate SMS numbers.
        ///   - overrides: An optional closure for overriding validation logic.
        public init(
            smsValidatorAPIClient: any SMSValidatorAPIClientProtocol,
            overrides: OverridesClosure? = nil
        ) {
            self.overrides = overrides
            self.smsValidatorAPIClient = smsValidatorAPIClient
        }

        /// Initializes the validator using a configuration object.
        /// - Parameter config: The runtime configuration used for initializing the validator.
        public convenience init(config: RuntimeConfig) {
            self.init(
                smsValidatorAPIClient: CachingSMSValidatorAPIClient(
                    client: SMSValidatorAPIClient(config: config)
                ),
                overrides: config.airshipConfig.inputValidationOverrides
            )
        }

        /// Validates the provided request asynchronously.
        /// - Parameter request: The request to be validated (either SMS or Email).
        /// - Throws: Can throw errors if validation fails or on cancellation.
        /// - Returns: The validation result, either valid or invalid.
        public func validateRequest(_ request: Request) async throws -> Result {
            try Task.checkCancellation()

            AirshipLogger.debug("Validating input request \(request)")

            if let overrides {
                AirshipLogger.trace("Attempting to use overrides for request \(request)")

                switch(try await overrides(request)) {
                case .override(let result):
                    AirshipLogger.debug("Overrides result \(result) for request \(request)")
                    return result
                case .useDefault:
                    AirshipLogger.trace("Overrides skipped, using default method for request \(request)")
                    break
                }
            }

            try Task.checkCancellation()

            let result = switch(request) {
            case .sms(let sms):
                try await validateSMS(sms, request: request)
            case .email(let email):
                try await validateEmail(email, request: request)
            }

            AirshipLogger.debug("Result \(result) for request \(request)")
            return result
        }

        /// Validates an email address.
        /// - Parameter email: The email to be validated.
        /// - Parameter request: The original request associated with the email.
        /// - Throws: Can throw errors during validation or cancellation.
        /// - Returns: The result of the email validation, either valid or invalid.
        private func validateEmail(_ email: Request.Email, request: Request) async throws -> Result {
            let address = email.rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let predicate = NSPredicate(format: "SELF MATCHES %@", Self.emailRegex)

            guard predicate.evaluate(with: address) else {
                return .invalid
            }
            return .valid(address: address)
        }

        /// Validates an SMS number.
        /// - Parameter sms: The SMS object containing validation information.
        /// - Parameter request: The original request associated with the SMS.
        /// - Throws: Can throw errors during validation or cancellation.
        /// - Returns: The result of the SMS validation, either valid or invalid.
        private func validateSMS(_ sms: Request.SMS, request: Request) async throws -> Result {
            guard sms.validationHints?.matches(sms.rawInput) != false else {
                AirshipLogger.trace("SMS validation failed for \(request), did not pass validation hints")
                return .invalid
            }

            // Airship SMS validation
            let result = switch(sms.validationOptions) {
            case .sender(let sender, _):
                try await smsValidatorAPIClient.validateSMS(msisdn: sms.rawInput, sender: sender)
            case .prefix(let prefix):
                try await smsValidatorAPIClient.validateSMS(msisdn: sms.rawInput, prefix: prefix)
            }

            // Assume client errors are not valid
            guard result.isClientError == false else { return .invalid }

            // Make sure we have a result, if not throw an error
            guard result.isSuccess, let value = result.result else {
                throw AirshipErrors.error("Failed to validate SMS \(result)")
            }

            // Convert the result
            return switch (value) {
            case .invalid: .invalid
            case .valid(let address): .valid(address: address)
            }
        }
    }
}
/// Extension to add matching logic for SMS validation hints (e.g., minimum or maximum digits).
fileprivate extension AirshipInputValidation.Request.SMS.ValidationHints {

    func matches(_ rawInput: String) -> Bool {
        let digits = rawInput.filter { $0.isNumber }

        guard
            digits.count >= (self.minDigits ?? 0),
            digits.count <= (self.maxDigits ?? Int.max)
        else {
            return false
        }

        return true
    }
}
