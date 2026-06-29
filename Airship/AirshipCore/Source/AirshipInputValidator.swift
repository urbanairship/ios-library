/* Copyright Airship and Contributors */

import Foundation
import Combine
@_spi(AirshipInternal) import AirshipBasement

extension AirshipInputValidation {
    /// A default implementation of the `Validator` protocol that uses a standard SMS validation API.
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
                @unknown default:
                    AirshipLogger.trace("Unknown override, using default method for request \(request)")
                    break
                }
            }

            try Task.checkCancellation()

            let result = switch(request) {
            case .sms(let sms):
                try await validateSMS(sms, request: request)
            case .email(let email):
                try await validateEmail(email, request: request)
            @unknown default:
                throw AirshipErrors.error("Unknown input validation request \(request)")
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
            @unknown default:
                throw AirshipErrors.error("Unknown SMS validation option \(sms.validationOptions)")
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
