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
    let inputValidator: (any AirshipInputValidation.Validator)?

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

    private var validatedAddress: String?

    internal init(
        item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt,
        theme: PreferenceCenterTheme.ContactManagement?,
        registrationOptions: PreferenceCenterConfig.ContactManagementItem.Platform?,
        onCancel: @escaping () -> Void,
        onRegisterSMS: @escaping (_ msisdn: String, _ senderID: String) -> Void,
        onRegisterEmail: @escaping (_ email: String) -> Void,
        validator: (any AirshipInputValidation.Validator)? = nil
    ) {
        self.item = item
        self.theme = theme
        self.platform = registrationOptions
        self.onCancel = onCancel
        self.onRegisterSMS = onRegisterSMS
        self.onRegisterEmail = onRegisterEmail
        self.selectedSender = .none
        self.inputValidator = if Airship.isFlying {
            validator ?? Airship.requireComponent(
                ofType: PreferenceCenterComponent.self
            ).preferenceCenter.inputValidator
        } else {
            validator
        }
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

            let smsRequest: AirshipInputValidation.Request = .sms(
                AirshipInputValidation.Request.SMS(
                    rawInput: self.inputText,
                    validationOptions: .sender(senderID: selectedSender.senderId, prefix: selectedSender.countryCode),
                    validationHints: .init(minDigits: 4)
                )
            )

            /// Attempt validation call
            let passedValidation = try await inputValidator?.validateRequest(smsRequest) ?? .invalid

            if case let .valid(address) = passedValidation {
                validatedAddress = address
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

        let emailRequest: AirshipInputValidation.Request = .email(
            AirshipInputValidation.Request.Email(
                rawInput: self.inputText
            )
        )

        do {
            let passedValidation = try await inputValidator?.validateRequest(emailRequest) ?? .invalid

            if case let .valid(address) = passedValidation {
                validatedAddress = address
                onValidationSucceeded()
            } else {
                onValidationFailed()
            }
        } catch {
            AirshipLogger.error(error.localizedDescription)
            onValidationError()
        }
    }

    internal func onSubmit() {
        if let platform = platform, let validatedAddress = validatedAddress {
            switch platform {
            case .sms(_):
                onRegisterSMS(validatedAddress, selectedSender.senderId)
            case .email(_):
                onRegisterEmail(validatedAddress)
            }
        }

        validatedAddress = nil
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

    /// Validates input format for UI feedback (enabling/disabling submit button)
    @MainActor
    internal func validateInputFormat() {
        if let platform = self.platform {
            // Basic validation to enable/disable submit button
            // Full validation happens in attemptSubmission
            switch platform {
            case .email(_):
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                isInputFormatValid = emailPredicate.evaluate(with: inputText)
            case .sms(_):
                let formattedPhone = inputText.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                isInputFormatValid = formattedPhone.count >= 7
            }
        } else {
            isInputFormatValid = false
        }
    }
}
