/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

public enum RegistrationState {
    case `failed`
    case succeed
    case inProgress(Bool)
}

// MARK: Add channel view
public struct AddChannelView: View {
    
    static let placeHolderPadding = EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 4)
    
    /// The alert width
    static let alertWidth = 300.0
    
    var item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt
    
    var state: Binding<RegistrationState>
    
    var onClose: (()->())?
    
    var onCancel: (()->())?
    
    var onSubmit: (()->())?
    
    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?
    
    var registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?
    
    @State
    private var selectedSender = PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo.none
    
    @State
    private var inputText = ""
    
    @State
    private var startEditing = false
    
    @State
    private var isValid = false
    
    public init(
        item: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt,
        theme: PreferenceCenterTheme.ContactManagement? = nil,
        registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?,
        state: Binding<RegistrationState>,
        onClose: (()->())? = nil,
        onCancel: (()->())? = nil,
        onSubmit: (()->())? = nil
    ) {
        self.item = item
        self.theme = theme
        self.registrationOptions = registrationOptions
        self.state = state
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        self.onClose = onClose
    }
    
    @ViewBuilder
    public var body: some View {
        Group {
            switch self.state.wrappedValue {
            case .failed:
                AlertView(
                    item: self.item.onError
                ) {
                    withAnimation {
                        self.state.wrappedValue = .inProgress(false)
                    }
                }
                .transition(.scale)
            case .succeed:
                AlertView(
                    item: self.item.onSuccess
                ) {
                    if let onClose = self.onClose {
                        onClose()
                    }
                }
                .transition(.scale)
            case .inProgress(let state):
                createPromptView(state)
            }
        }
        .background(Color.clear)
    }
    
    // MARK: Prompt view
    @ViewBuilder
    private func createPromptView(_ inprogress: Bool) -> some View {
        GeometryReader { proxy in
            VStack(alignment: .leading) {
                /// Title
                Text(self.item.display.title)
                    .textAppearance(
                        theme?.titleAppearance,
                        base: DefaultContactManagementSectionStyle.titleAppearance
                    )
                    .fixedSize(horizontal: false, vertical: true)
                
                /// Subtitle
                if let subtitle = self.item.display.body {
                    Text(subtitle)
                        .textAppearance(
                            theme?.subtitleAppearance,
                            base: DefaultContactManagementSectionStyle.subtitleAppearance
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                /// Channel Input text fiels
                ChannelTextField(
                    registrationOptions: self.registrationOptions, 
                    selectedSender: self.$selectedSender,
                    inputText: self.$inputText,
                    isValid: self.$isValid,
                    startEditing: self.$startEditing
                )
                
                /// Error Message
                if self.startEditing && !isValid {
                    ErrorMessageView(
                        message: self.item.display.errorMessage,
                        theme: self.theme
                    )
                    .transition(.scale)
                }
                
                HStack {
                    /// Cancel button
                    LabeledButton(
                        item: self.item.cancelButton,
                        theme: self.theme) {
                            if let onCancel = self.onCancel {
                                onCancel()
                            }
                        }
                    
                    Spacer()
                    
                    /// Submit button
                    LabeledButton(
                        item: self.item.submitButton,
                        enabled: self.$isValid,
                        theme: self.theme) {
                            self.state.wrappedValue = .inProgress(true)
                            registerChannel()
                            if let onSubmit = self.onSubmit {
                                onSubmit()
                            }
                        }
                }
                
                Spacer()
                    .frame(height: 20)
                
                /// Footer
                if let footer = self.item.display.footer {
                    Text(footer)
                        .textAppearance(
                            theme?.subtitleAppearance,
                            base: DefaultContactManagementSectionStyle.subtitleAppearance
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .background(
                BackgroundShape(
                    color: theme?.backgroundColor ?? DefaultContactManagementSectionStyle.backgroundColor
                )
            )
            .position(x: proxy.frame(in: .local).midX, y: proxy.frame(in: .local).midY)
            .transition(.scale)
            .applyIf(inprogress) { content in
                content.overlay(
                    ProgressView(),
                    alignment: .center
                )
            }
        }
    }
    
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


// MARK: Channel text field
public struct ChannelTextField: View {
    
    private var senders: [PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo]?
    
    private var registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?
    
    private var selectedSender: Binding<PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo>
    
    private var inputText: Binding<String>
    
    private var startEditing: Binding<Bool>
    
    private var isValid: Binding<Bool>
    
    public init(
        registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?,
        selectedSender: Binding<PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo>,
        inputText: Binding<String>,
        isValid: Binding<Bool>,
        startEditing: Binding<Bool>
    ) {
        self.registrationOptions = registrationOptions
        self.selectedSender = selectedSender
        self.inputText = inputText
        self.startEditing = startEditing
        self.isValid = isValid
        if case .sms(let smsOptions) = self.registrationOptions {
            self.senders = smsOptions.senders
        }
    }
    
    public var body: some View {
        createTextField()
    }
    
    // MARK: TextField
    private func createTextField() -> some View {
        return HStack {
            if let senders = self.senders, (senders.count >= 1) {
                Picker("senders", selection: selectedSender) {
                    ForEach(senders, id: \.self) {
                        Text($0.countryCode)
                    }
                }
            }
            
            HStack {
                TextField(placeHolder(), text: inputText)
                    .padding(AddChannelView.placeHolderPadding)
                    .keyboardType(keyboardType)
                    .airshipOnChangeOf(self.inputText.wrappedValue) { newValue in
                        startEditing.wrappedValue = true
                        isValid.wrappedValue = isValidInput()
                    }
            }
            .border(.gray)
            .cornerRadius(3.0)
        }
        .onAppear {
            if let sender = self.senders?.first {
                self.selectedSender.wrappedValue = sender
            }
        }
    }
    
    // MARK: Keyboard type
    private var keyboardType: UIKeyboardType {
        if let registrationOptions = self.registrationOptions {
            switch registrationOptions {
            case .sms(_):
                return .decimalPad
            case .email(_):
                return .emailAddress
            }
        } else {
            return .default
        }
    }
    
    // MARK: Place holder
    private func placeHolder() -> String {
        let defaultPlaceHolder = ""
        if let registrationOptions = self.registrationOptions {
            switch registrationOptions {
            case .sms(_):
                return self.selectedSender.wrappedValue.placeHolderText
            case .email(let emailRegistrationOption):
                return emailRegistrationOption.placeholder
            }
        } else {
            return defaultPlaceHolder
        }
    }
    
    // MARK: Validate input
    private func isValidInput() -> Bool {
        if let registrationOptions = self.registrationOptions {
            switch registrationOptions {
            case .email(_):
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                return emailPredicate.evaluate(with: self.inputText.wrappedValue)
            case .sms(_):
                let trimmed = self.inputText.wrappedValue.replacingOccurrences(of: " ", with: "")
                let phoneRegex = "^[0-9]+$"
                let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
                return phoneTest.evaluate(with: trimmed)
            }
        } else {
            return false
        }
    }
}

// MARK: Alert view: error/succeed alert view
public struct AlertView: View {
    
    var item: PreferenceCenterConfig.ContactManagementItem.ActionableMessage?
    
    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?
    
    var action: (()->())?
    
    public init(
        item: PreferenceCenterConfig.ContactManagementItem.ActionableMessage? = nil, 
        theme: PreferenceCenterTheme.ContactManagement? = nil,
        action: (() -> Void)? = nil
    ) {
        self.item = item
        self.theme = theme
        self.action = action
    }
    
    public var body: some View {
        
        if let item = self.item {
            VStack(alignment: .leading) {
                
                /// Title
                Text(item.title)
                    .textAppearance(
                        theme?.titleAppearance,
                        base: DefaultContactManagementSectionStyle.titleAppearance
                    )
                
                /// Body
                Text(item.body)
                    .textAppearance(
                        theme?.subtitleAppearance,
                        base: DefaultContactManagementSectionStyle.subtitleAppearance
                    )
                
                /// Button
                LabeledButton(
                    item: item.button,
                    theme: self.theme,
                    action: action
                )
            }
            .frame(width: AddChannelView.alertWidth)
            .padding()
            .background(
                BackgroundShape(
                    color: theme?.backgroundColor ?? DefaultContactManagementSectionStyle.backgroundColor
                )
            )
        }
    }
}

// MARK: Error message view
public struct ErrorMessageView: View {
    
    public var message: String?
    var theme: PreferenceCenterTheme.ContactManagement?
    
    public init(
        message: String?,
        theme: PreferenceCenterTheme.ContactManagement?
    ) {
        self.message = message
        self.theme = theme
    }
    
    public var body: some View {
        if let errorMessage = self.message {
            HStack (alignment: .top){
                Image(systemName: "exclamationmark.circle")
                    .imageScale(.large)
                    .foregroundColor(theme?.errorAppearance?.color ?? DefaultContactManagementSectionStyle.defaultErrorAppearance.color)
                Text(errorMessage)
                    .textAppearance(
                        theme?.errorAppearance,
                        base: DefaultContactManagementSectionStyle.defaultErrorAppearance
                    )
                    .lineLimit(2)
            }
        }
    }
}
