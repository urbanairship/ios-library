/* Copyright Airship and Contributors */

public import SwiftUI
import Combine

// MARK: Channel text field
public struct ChannelTextField: View {
    // MARK: - Constants
    private enum Layout {
        #if os(tvOS)
        static let fieldHeight: CGFloat = 66  // tvOS needs taller fields for focus
        static let fieldPadding: CGFloat = 12
        #else
        static let fieldHeight: CGFloat = 52
        static let fieldPadding: CGFloat = 10
        #endif
        static let fieldCornerRadius: CGFloat = 4
        static let stackSpacing: CGFloat = 2
        static let standardSpacing: CGFloat = 12
        static let placeHolderPadding = EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 4)
    }

    // MARK: - Environment
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Properties
    private var senders: [PreferenceCenterConfig.ContactManagementItem.SMSSenderInfo]?
    private var platform: PreferenceCenterConfig.ContactManagementItem.Platform?
    private var smsOptions: PreferenceCenterConfig.ContactManagementItem.SMS?
    private var emailOptions: PreferenceCenterConfig.ContactManagementItem.Email?

    // MARK: - State
    @Binding var selectedSender: PreferenceCenterConfig.ContactManagementItem.SMSSenderInfo
    @State var selectedSenderID: String = ""
    @Binding var inputText: String
    @State private var placeholder: String = ""

    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?

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
        VStack(spacing: Layout.standardSpacing) {
            countryPicker
            
            VStack {
                HStack(spacing: Layout.stackSpacing) {
                    textFieldLabel
                    textField
                }
                .padding(Layout.fieldPadding)
                .background(backgroundView)
            }
            .frame(height: Layout.fieldHeight)
        }
        .frame(maxWidth: .infinity)
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
            .padding(.horizontal)
            .frame(height: Layout.fieldHeight)
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
            .padding(Layout.placeHolderPadding)
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

        RoundedRectangle(cornerRadius: Layout.fieldCornerRadius)
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
