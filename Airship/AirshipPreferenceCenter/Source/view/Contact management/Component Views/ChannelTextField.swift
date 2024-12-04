/* Copyright Airship and Contributors */

import SwiftUI
import Combine

// MARK: Channel text field
public struct ChannelTextField: View {
    @Environment(\.colorScheme) var colorScheme

    private let placeHolderPadding = EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 4)

    private var senders: [PreferenceCenterConfig.ContactManagementItem.SMSSenderInfo]?

    private var platform: PreferenceCenterConfig.ContactManagementItem.Platform?

    @Binding var selectedSender: PreferenceCenterConfig.ContactManagementItem.SMSSenderInfo

    @State var selectedSenderID: String = ""

    @Binding var inputText: String

    @State
    private var placeholder: String = ""

    private let fieldCornerRadius: CGFloat = 4

    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?

    private var smsOptions: PreferenceCenterConfig.ContactManagementItem.SMS?
    private var emailOptions: PreferenceCenterConfig.ContactManagementItem.Email?

    public init(
        platform: PreferenceCenterConfig.ContactManagementItem.Platform?,
        selectedSender: Binding<PreferenceCenterConfig.ContactManagementItem.SMSSenderInfo>,
        inputText: Binding<String>,
        theme: PreferenceCenterTheme.ContactManagement?
    ) {
        self.platform = platform
        _selectedSender = selectedSender
        _inputText = inputText

        self.theme = theme

        if let platform = self.platform {
            switch platform {
            case .sms(let options):
                self.senders = options.senders
                smsOptions = options
            case .email(let options):
                emailOptions = options
            }
        }

        self.placeholder = makePlaceholder()
    }

    public var body: some View {
        countryPicker
        VStack {
            HStack(spacing:2) {
                textFieldLabel
                textField
            }
            .padding(10)
            .background(backgroundView)
        }
    }

    @ViewBuilder
    private var countryPicker: some View {
        /// Use text field color for picker accent. May want to expose this separately at some point.
        let pickerAccent = colorScheme.airshipResolveColor(light: theme?.textFieldTextAppearance?.color, dark: theme?.textFieldTextAppearance?.colorDark)
        if let senders = self.senders, (senders.count >= 1) {
            HStack {
                if let smsOptions = smsOptions {
                    Text(smsOptions.countryLabel).textAppearance(
                        theme?.textFieldPlaceholderAppearance,
                        base: PreferenceCenterDefaults.textFieldTextAppearance,
                        colorScheme: colorScheme
                    )
                }
                Spacer()
                Picker("senders", selection: $selectedSenderID) {
                    ForEach(senders, id: \.self) {
                        Text($0.displayName).textAppearance(
                            theme?.textFieldPlaceholderAppearance,
                            base: PreferenceCenterDefaults.textFieldTextAppearance,
                            colorScheme: colorScheme
                        ).tag($0.senderId)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(pickerAccent ?? AirshipSystemColors.label)
                .airshipOnChangeOf(self.selectedSenderID, { newVal in
                    if let sender = senders.first(where: { $0.senderId == newVal }) {
                        selectedSender = sender
                        /// Update placeholder with selection
                        placeholder = makePlaceholder()
                    }
                })
                .onAppear {
                    /// Ensure initial value is set
                    if let sender = self.senders?.first {
                        self.selectedSenderID = sender.senderId
                    }
                }
            }
            .padding()
            .background(backgroundView)
        }
    }

    @ViewBuilder
    private var textField: some View {
        let textColor = colorScheme.airshipResolveColor(
            light: theme?.textFieldTextAppearance?.color,
            dark: theme?.textFieldTextAppearance?.colorDark
        )

        TextField(makePlaceholder(), text: $inputText)
            .foregroundColor(textColor)
            .padding(self.placeHolderPadding)
            .keyboardType(keyboardType)
    }

    @ViewBuilder
    private var textFieldLabel: some View {
        if let smsOptions = smsOptions {
            Text(smsOptions.msisdnLabel)
                .textAppearance(
                    theme?.textFieldPlaceholderAppearance,
                    base: PreferenceCenterDefaults.textFieldTextAppearance,
                    colorScheme: colorScheme
                )
        } else if let emailOptions = emailOptions {
            Text(emailOptions.addressLabel)
                .textAppearance(
                theme?.textFieldPlaceholderAppearance,
                base: PreferenceCenterDefaults.textFieldTextAppearance,
                colorScheme: colorScheme
            )
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        let backgroundColor = colorScheme.airshipResolveColor(
            light: theme?.backgroundColor,
            dark: theme?.backgroundColorDark
        ) ?? AirshipSystemColors.background

        RoundedRectangle(cornerRadius: fieldCornerRadius)
            .foregroundColor(backgroundColor.secondaryVariant(for: colorScheme).opacity(0.2))
    }

    // MARK: Keyboard type
    private var keyboardType: UIKeyboardType {
        if let platform = self.platform {
            switch platform {
            case .sms(_):
                return .decimalPad
            case .email(_):
                return .emailAddress
            }
        } else {
            return .default
        }
    }

    // MARK: Placeholder
    private func makePlaceholder() -> String {
        let defaultPlaceholder = ""
        if let platform = self.platform {
            switch platform {
            case .sms(_):
                return self.selectedSender.placeholderText
            case .email(let emailRegistrationOption):
                return emailRegistrationOption.placeholder ?? defaultPlaceholder
            }
        } else {
            return defaultPlaceholder
        }
    }
}
