/* Copyright Airship and Contributors */

import Foundation


/// NOTE: For internal use only. :nodoc:
public struct AirshipInputValidator: Sendable {

    /// Phone Number validation arguments.
    public enum PhoneNumberValidation: Sendable, Equatable {
        /// Sender argument for phone number validation.
        case sender(String)
    }

    /// Represents a phone number.
    public struct PhoneNumber: Sendable, Equatable {
        /// The formatted phone number address.
        public let address: String

        /// Validates the format of the phone number using a regex pattern.
        public var isValidFormat: Bool {
            // E.164 format
            let regex = "^[1-9]\\d{1,14}$"
            let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
            return predicate.evaluate(with: address)
        }

        /// Initializes a PhoneNumber instance by cleaning and formatting the provided phone number.
        /// - Parameters:
        ///   - msisdn: The phone number to format.
        ///   - countryCode: The country code to be included in the formatted number.
        public init(_ msisdn: String, countryCode: String) {

            /// Format for MSISDN  standards - including removing plus, dashes, spaces etc.
            /// Formatting behind the scenes like this makes sense because there are lots of valid ways to show
            /// Phone numbers like 1.503.867.5309 1-504-867-5309. This also allows us to strip the "+" from the country code

            let cleanedCountryCode = countryCode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            var cleanedNumber = msisdn.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

            // Remove country code from the beginning of the number if it's already present
            if cleanedNumber.hasPrefix(cleanedCountryCode) {
                cleanedNumber = String(cleanedNumber.dropFirst(cleanedCountryCode.count))
            }
            self.address = cleanedCountryCode + cleanedNumber
        }
    }

    /// Represents an email address.
    public struct Email: Sendable, Equatable {
        /// The formatted email address.
        public let address: String

        /// Validates the format of the email using a regex pattern.
        public var isValidFormat: Bool {
            // checks for <ANYTHING>@<ANYTHING>.<ANYTHING>
            let regex = #"^[^@\s]+@[^@\s]+\.[^@\s.]+$"#
            let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
            return predicate.evaluate(with: address)
        }

        /// Initializes an Email instance by cleaning and formatting the provided email.
        /// - Parameters:
        ///   - email: The email to format.
        public init(_ email: String) {
            self.address = email.trimmingCharacters(in: .whitespaces)
        }
    }

    private let onValidatePhoneNumber: @Sendable (PhoneNumber, PhoneNumberValidation) async throws -> Bool

    /// Initializes a validator instance with a custom phone number validation block.
    /// - Parameters:
    ///   - onValidatePhoneNumber: A block to run when a phone number needs to be validated.
    public init(onValidatePhoneNumber: @Sendable @escaping (PhoneNumber, PhoneNumberValidation) -> Bool) {
        self.onValidatePhoneNumber = onValidatePhoneNumber
    }

    /// Initializes a validator instance with the default validation logic for phone numbers.
    public init() {
        self.onValidatePhoneNumber = { phoneNumber, validation in
            switch(validation) {
            case .sender(let sender):
                // Sends an SMS validation request via Airship's contact service
                return try await Airship.contact.validateSMS(phoneNumber.address, sender: sender)
            }
        }
    }

    /// Validates a phone number.
    /// - Parameters:
    ///   - phoneNumber: The phone number to validate.
    ///   - validation: Validation arguments (e.g., sender).
    /// - Returns: `true` if valid format and successfully validated, otherwise `false`.
    public func validate(phoneNumber: PhoneNumber, validation: PhoneNumberValidation) async throws -> Bool {
        guard phoneNumber.isValidFormat else {
            return false
        }
        return try await onValidatePhoneNumber(phoneNumber, validation)
    }

    /// Validates an email address.
    /// - Parameters:
    ///   - email: The email to validate.
    /// - Returns: `true` if valid format, otherwise `false`.
    /// - Note: This method only checks if the email has a valid format, not if the email exists.
    public func validate(email: Email) -> Bool {
        guard email.isValidFormat else {
            return false
        }
        return true
    }
}
