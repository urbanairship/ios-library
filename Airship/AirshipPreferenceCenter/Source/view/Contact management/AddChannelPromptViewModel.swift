/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

/// Imported for Logger and Contact calls
#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
internal class AddChannelPromptViewModel: ObservableObject {
    @Published var state: AddChannelState = .ready
    @Published var selectedSender: PreferenceCenterConfig.ContactManagementItem.SMSSenderInfo
    @Published var inputText = ""
    @Published var isInputFormatValid = false

    var theme: PreferenceCenterTheme.ContactManagement?

    internal let item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt
    internal let platform: PreferenceCenterConfig.ContactManagementItem.Platform?
    internal let onCancel: () -> Void
    internal let onRegisterSMS: (_ msisdn: String, _ senderID: String) -> Void
    internal let onRegisterEmail: (_ email: String) -> Void

    internal init(
        item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt,
        theme: PreferenceCenterTheme.ContactManagement?,
        registrationOptions: PreferenceCenterConfig.ContactManagementItem.Platform?,
        onCancel: @escaping () -> Void,
        onRegisterSMS: @escaping (_ msisdn: String, _ senderID: String) -> Void,
        onRegisterEmail: @escaping (_ email: String) -> Void
    ) {
        self.item = item
        self.theme = theme
        self.platform = registrationOptions
        self.onCancel = onCancel
        self.onRegisterSMS = onRegisterSMS
        self.onRegisterEmail = onRegisterEmail
        self.selectedSender = .none
    }

    /// Attempts submission and updates state based on results of attempt
    @MainActor
    internal func attemptSubmission() {
        Task {
            if platform?.channelType == .sms {
                await attemptSMSSubmission()
            } else {
                await attemptEmailSubmission()
            }
        }
    }

    @MainActor
    private func attemptSMSSubmission() async {
        do {
            let formattedMSISDN = formattedMSISDN(countryCode: selectedSender.countryCode, number: inputText)

            /// Only start to load when we are sure it's not a duplicate failed request
            onStartLoading()

            /// Attempt validation call
            let passedValidation = try await validateSMS(msisdn: formattedMSISDN, sender: selectedSender.senderId)

            if passedValidation {
                onValidationSucceeded()
            } else {
                onValidationFailed()
            }

            return
        } catch {
            AirshipLogger.error(error.localizedDescription)
        }

        /// Even if an error is thrown, if this ever is hit something went wrong, show it as a generic error
        onValidationError()
    }

    @MainActor
    private func attemptEmailSubmission() async {
        onStartLoading()

        /// Attempt email validation (just regex for now)
        let passedValidation = validateInputFormat()

        if passedValidation {
            onValidationSucceeded()
        } else {
            onValidationFailed()
        }
    }

    internal func onSubmit() {
        if let platform = platform {
            switch platform {
            case .sms(_):
                let formattedNumber = formattedMSISDN(countryCode: selectedSender.countryCode, number: inputText)
                onRegisterSMS(formattedNumber, selectedSender.senderId)
            case .email(_):
                let formattedEmail = formattedEmail(email: inputText)
                onRegisterEmail(formattedEmail)
            }
        }
    }

    @MainActor
    internal func onStartLoading() {
        withAnimation {
            self.state = .loading
        }
    }

    @MainActor
    internal func onValidationSucceeded() {
        withAnimation {
            self.state = .succeeded
        }
    }

    @MainActor
    private func onValidationFailed() {
        withAnimation {
            self.state = .failedInvalid
        }
    }

    @MainActor
    private func onValidationError() {
        withAnimation {
            self.state = .failedDefault
        }
    }
}

// MARK: Remote operations

extension AddChannelPromptViewModel {
    @MainActor
    private func validateSMS(msisdn: String, sender: String) async throws -> Bool {
        if let delegate = Airship.contact.smsValidatorDelegate {
            let result = try await delegate.validateSMS(msisdn: msisdn, sender: sender)
            AirshipLogger.trace("Validating phone number through delegate")
            return result
        } else {
            let result = try await Airship.contact.validateSMS(msisdn, sender: sender)
            AirshipLogger.trace("Using default phone number validator")
            return result
        }
    }
}

// MARK: Utilities
extension AddChannelPromptViewModel {

    /// Format for MSISDN  standards - including removing plus, dashes, spaces etc.
    /// Formatting behind the scenes like this makes sense because there are lots of valid ways to show
    /// Phone numbers like 1.503.867.5309 1-504-867-5309. This also allows us to strip the "+" from the country code
    func formattedMSISDN(countryCode: String, number: String) -> String {
        let cleanedCountryCode = countryCode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        var cleanedNumber = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // Remove country code from the beginning of the number if it's already present
        if cleanedNumber.hasPrefix(cleanedCountryCode) {
            cleanedNumber = String(cleanedNumber.dropFirst(cleanedCountryCode.count))
        }

        let msisdn = cleanedCountryCode + cleanedNumber
        return msisdn
    }

    /// Just trim spaces for emails to be helpful
    func formattedEmail(email: String) -> String {
        let trimmedText = email.replacingOccurrences(of: " ", with: "")
        return String(trimmedText)
    }

    /// Initial validation that unlocks the submit button. Email is currently only validated via this method.
    @MainActor
    internal func validateInputFormat() -> Bool {
        if let platform = self.platform {
            switch platform {
            case .email(_):
                return self.inputText.airshipIsValidEmail()
            case .sms(_):
                let formatted = formattedMSISDN(countryCode: self.selectedSender.countryCode, number: self.inputText)
                let msisdnRegex = "^[1-9]\\d{1,14}$"
                let msisdnPredicate = NSPredicate(format: "SELF MATCHES %@", msisdnRegex)
                return msisdnPredicate.evaluate(with: formatted)
            }
        } else {
            return false
        }
    }
}
