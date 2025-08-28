/* Copyright Airship and Contributors */

/// Delegate for overriding the default SMS validation.
/// Deprecated, app should use `AirshipConfig.inputValidationOverrides` instead.
public protocol SMSValidatorDelegate: Sendable {

    /**
     * Validates a given MSISDN.
     * - Parameters:
     *   - msisdn: The msisdn to validate.
     *   - sender: The identifier given to the sender of the SMS message.
     * - Returns: `true` if the phone number is valid, otherwise `false`.
     */
    @MainActor
    func validateSMS(msisdn: String, sender: String) async throws -> Bool
}
