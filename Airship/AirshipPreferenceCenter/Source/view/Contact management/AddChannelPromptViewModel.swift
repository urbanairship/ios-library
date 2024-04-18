/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

/// Imported for Logger and Contact calls
#if canImport(AirshipCore)
import AirshipCore
#endif

internal class AddChannelPromptViewModel: ObservableObject {
    @Published var state: AddChannelState = .ready
    @Published var selectedSender: PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo
    @Published var inputText = ""
    @Published var isInputFormatValid = false

    var theme: PreferenceCenterTheme.ContactManagement?

    internal let item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt
    internal let registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?
    internal let onCancel: () -> Void
    internal let onSubmit: () -> Void

    internal init(
        item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt,
        theme: PreferenceCenterTheme.ContactManagement?,
        registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping () -> Void
    ) {
        self.item = item
        self.theme = theme
        self.registrationOptions = registrationOptions
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        self.selectedSender = .none
    }

    /// Attempts submission and updates state based on results of attempt
    @MainActor
    internal func attemptSubmission() {
        Task {
            if registrationOptions?.isSms == true {
                await attemptSMSSubmission()
            } else {
                /// Email we just assume is good to go after format check
                /// if a failure occurs it will be determined by the channel update response
                /// in the channel list view
                onValidationSucceeded()
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
        registerChannel()
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
        if let delegate = Airship.contact.SMSValidatorDelegate {
            let result = try await delegate.validateSMS(msisdn: msisdn, sender: sender)
            AirshipLogger.trace("Validating phone number through delegate")
            return result
        } else {
            let result = try await Airship.contact.validateSMS(msisdn, sender: sender)
            AirshipLogger.trace("Using default phone number validator")
            return result
        }
    }

    private func registerChannel() {
        if let registrationOptions = registrationOptions {
            switch registrationOptions {
            case .sms(_):
                let formattedNumber = formattedMSISDN(countryCode: selectedSender.countryCode, number: inputText)
                let options = SMSRegistrationOptions.optIn(
                    senderID: selectedSender.senderId
                )
                Airship.contact.registerSMS(formattedNumber, options: options)
            case .email(_):
                let date = Date()
                let options = EmailRegistrationOptions.commercialOptions(
                    transactionalOptedIn: date,
                    commercialOptedIn: date,
                    properties: nil
                )

                Airship.contact.registerEmail(
                    formattedEmail(email: inputText),
                    options: options
                )
            }
        }
    }
}

// MARK: Utilities
extension AddChannelPromptViewModel {

    /// Format for MSISDN  standards - including removing plus, dashes, spaces etc.
    /// Formatting behind the scenes like this makes sense because there are lots of valid ways to show
    /// Phone numbers like 1.503.867.5309 1-504-867-5309. This also allows us to strip the "+" from the country code
    func formattedMSISDN(countryCode: String, number: String) -> String {
        let msisdn = countryCode + number
        let allowedCharacters = CharacterSet.decimalDigits
        let formatted = msisdn.unicodeScalars.filter { allowedCharacters.contains($0) }
        return String(formatted)
    }

    /// Just trim spaces for emails to be helpful
    func formattedEmail(email: String) -> String {
        let trimmedText = email.replacingOccurrences(of: " ", with: "")
        return String(trimmedText)
    }

    /// Initial validation that unlocks the submit button. Email is currently only validated via this method.
    @MainActor
    internal func validateInputFormat() -> Bool {
        if let registrationOptions = self.registrationOptions {
            switch registrationOptions {
            case .email(_):
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                return emailPredicate.evaluate(with: self.inputText)
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
