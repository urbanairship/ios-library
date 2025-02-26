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
    let inputValidator = AirshipInputValidator()

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
            /// Only start to load when we are sure it's not a duplicate failed request
            onStartLoading()

            let phoneNumber = AirshipInputValidator.PhoneNumber(
                self.inputText,
                countryCode: selectedSender.countryCode
            )

            /// Attempt validation call
            let passedValidation = try await inputValidator.validate(
                phoneNumber: phoneNumber,
                validation: .sender(selectedSender.senderId)
            )

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

        let email = AirshipInputValidator.Email(self.inputText)

        let passedValidation = inputValidator.validate(
            email: email
        )

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
                let phoneNumber = AirshipInputValidator.PhoneNumber(
                    self.inputText,
                    countryCode: selectedSender.countryCode
                )
                onRegisterSMS(phoneNumber.address, selectedSender.senderId)
            case .email(_):
                let email = AirshipInputValidator.Email(self.inputText)
                onRegisterEmail(email.address)
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

    /// Initial validation that unlocks the submit button. Email is currently only validated via this method.
    @MainActor
    internal func validateInputFormat() -> Bool {
        if let platform = self.platform {
            switch platform {
            case .email(_):
                return AirshipInputValidator.Email(self.inputText).isValidFormat
            case .sms(_):
                return AirshipInputValidator.PhoneNumber(
                    self.inputText,
                    countryCode: self.selectedSender.countryCode
                ).isValidFormat
            }
        } else {
            return false
        }
    }
}
