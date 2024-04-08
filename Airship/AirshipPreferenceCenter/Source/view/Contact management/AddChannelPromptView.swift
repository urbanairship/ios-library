/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

public enum AddChannelState {
    case failedInvalid
    case failedDefault
    case succeeded
    case ready
    case loading
}

// MARK: Add channel view
public struct AddChannelPromptView: View, @unchecked Sendable {
    /// The alert width
    static let alertWidth = 320.0

    var item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt

    var onCancel: ()->()

    /// TODO: Add type with input text
    var onSubmit: ()->()

    var validatorDelegate: PreferenceCenterValidatorDelegate?
    
    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?
    
    var registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?
    
    @State
    var state: AddChannelState = .ready

    @State
    private var selectedSender = PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo.none
    
    @State
    private var inputText = ""

    @State
    private var isInputFormatValid:Bool = false

    @State
    private var startEditing = false

    public init(
        item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt,
        theme: PreferenceCenterTheme.ContactManagement? = nil,
        registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?,
        validatorDelegate: PreferenceCenterValidatorDelegate?,
        onCancel: @escaping ()->(),
        onSubmit: @escaping ()->()
    ) {
        self.item = item
        self.theme = theme
        self.registrationOptions = registrationOptions
        self.validatorDelegate = validatorDelegate
        self.onCancel = onCancel
        self.onSubmit = onSubmit
    }

    @ViewBuilder
    public var foregroundContent: some View {
        switch self.state {
        case .succeeded:
            ActionableMessageView(
                item: self.item.onSuccess
            ) {
                self.dismiss()
            }
            .transition(.opacity)
        case .ready, .loading, .failedInvalid, .failedDefault:
            promptView
        }
    }

    @ViewBuilder
    public var body: some View {
        foregroundContent.backgroundWithCloseAction {
            self.dismiss()
        }
    }

    // MARK: Prompt view
    @ViewBuilder
    private var titleText: some View {
        Text(self.item.display.title)
            .textAppearance(
                theme?.titleAppearance,
                base: DefaultContactManagementSectionStyle.titleAppearance
            )
    }

    @ViewBuilder
    private var bodyText: some View {
        if let bodyText = self.item.display.body {
            Text(bodyText)
                .textAppearance(
                    theme?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
                )
        }
    }

    private var errorMessage : String? {
        switch self.state {
        case .failedInvalid:
            return self.item.errorMessages?.invalidMessage
        case .failedDefault:
            return self.item.errorMessages?.defaultMessage
        default:
            return nil
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if self.state == .failedDefault || self.state == .failedInvalid,
           let errorMessage = errorMessage {
            ErrorLabel(
                message: errorMessage,
                theme: self.theme
            )
            .transition(.opacity)
        }
    }

    func validateInput() async -> Bool {
        try? await Task.sleep(nanoseconds: UInt64(0.5 * 1000000000))
        return true
    }

    @ViewBuilder
    private var submitButton: some View {
        HStack {
            Spacer()

            /// Submit button
            LabeledButton(
                item: self.item.submitButton,
                isEnabled: self.isInputFormatValid,
                isLoading: self.state == .loading,
                theme: self.theme) {
                    withAnimation {
                        self.state = .loading
                    }
                    Task {
                        if await validateInput() {
                            registerChannel()

                            withAnimation {
                                self.state = .succeeded
                            }
                            /// TODO update register channel with failure state for when API fails
                            onSubmit()
                        } else {
                            withAnimation {
                                self.state = .failedInvalid
                            }
                        }
                    }
                }.applyIf(state == .loading) { content in
                    content.overlay(
                        ProgressView(),
                        alignment: .center
                    )
                }
        }
    }

    @ViewBuilder
    private var footer: some View {
        /// Footer
        if let footer = self.item.display.footer {
            Spacer()
                .frame(height: 20)
            Text(LocalizedStringKey(footer)) /// Markdown parsing in iOS15+
                .textAppearance(
                    theme?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
                )
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
        }
    }

    private func dismiss() {
        onCancel()
    }

    // TODO pull into the parent view model so it can be tested separately.
    // This responsibility should not belong to the component view
    // MARK: Validate input format
    private func validateInputFormat() -> Bool {
        if let registrationOptions = self.registrationOptions {
            switch registrationOptions {
            case .email(_):
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                return emailPredicate.evaluate(with: self.inputText)
            case .sms(_):
                let trimmed = self.inputText.replacingOccurrences(of: " ", with: "")
                let phoneRegex = "^[1-9]\\d{1,14}$"
                let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
                return phoneTest.evaluate(with: trimmed)
            }
        } else {
            return false
        }
    }

    @ViewBuilder
    private var promptViewContent: some View {
        VStack(alignment: .leading) {
            titleText.padding(.trailing, 16) // Pad out to prevent aliasing with the close button
            bodyText

            /// Channel Input text fields
            ChannelTextField(
                registrationOptions: self.registrationOptions,
                selectedSender: self.$selectedSender,
                inputText: self.$inputText,
                theme: self.theme
            )

            errorText
            submitButton
            footer
        }
    }

    var promptView: some View {
        GeometryReader { proxy in
            promptViewContent
            .padding(16)
            .addBackground(theme: theme)
            .addPreferenceCloseButton(dismissButtonColor: .primary, dismissIconResource: "xmark", onUserDismissed: {
                onCancel()
            })
            .padding(16)
            .position(x: proxy.frame(in: .local).midX, y: proxy.frame(in: .local).midY)
            .transition(.opacity)
            .onChange(of: inputText) { newValue in
                let isValid = validateInputFormat()

                withAnimation {
                    self.isInputFormatValid = isValid

                    if isValid {
                        self.state = .ready
                    }
                }
            }
        }
    }
    
    private func validateSMS(phoneNumber: String, sender: String) async {
        if let delegate = self.validatorDelegate {
            AirshipLogger.trace(
                "Validate phone number through delegate"
            )
            let _ = await delegate.validate(phoneNumber: phoneNumber, sender: sender)
        } else {
            AirshipLogger.trace("Use default phone number validator")
            Airship.contact.validateSMS(phoneNumber, sender: sender)
        }
    }

    /// TODO: Move out of the view itself
    // MARK: Register a new channel
    private func registerChannel() {
        if let registrationOptions = self.registrationOptions {
            let trimmedText = self.inputText.replacingOccurrences(of: " ", with: "");

            switch registrationOptions {
            case .sms(_):
                let trimmedPhoneNumber = (self.selectedSender.countryCode) + trimmedText
                let options = SMSRegistrationOptions.optIn(
                    senderID: self.selectedSender.senderId
                )
                Airship.contact.registerSMS(trimmedPhoneNumber, options: options)
            case .email(_):
                let date = Date()
                let options = EmailRegistrationOptions.commercialOptions(
                    transactionalOptedIn: date,
                    commercialOptedIn: date,
                    properties: nil
                )

                Airship.contact.registerEmail(
                    trimmedText,
                    options: options
                )
            }
        }
    }
}
