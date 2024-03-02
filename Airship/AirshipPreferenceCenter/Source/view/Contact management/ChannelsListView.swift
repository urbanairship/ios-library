/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

// MARK: Channel list view
public struct ChannelsListView: View {
    
    /// The item's config
    public let item: PreferenceCenterConfig.ContactManagementItem
    
    @ObservedObject
    public var state: PreferenceCenterState
    
    @Environment(\.airshipPreferenceCenterTheme)
    private var theme: PreferenceCenterTheme
    
    @State
    private var channels: [AssociatedChannel] = []
    
    @State
    var registrationState: RegistrationState = .inProgress(false)
    
    @State
    private var hideView: Bool = false
    
    @State
    private var disposable: AirshipMainActorCancellableBlock?

    @State
    private var subscriptions: Set<AnyCancellable> = []
    
    @State
    private var selectedChannel: AssociatedChannel?
    
    public init(
        item: PreferenceCenterConfig.ContactManagementItem,
        state: PreferenceCenterState
    ) {
        self.item = item
        self.state = state
    }
    
    public var body: some View {
        if !self.hideView {
            VStack {
                Section {
                    if self.channels.isEmpty {
                        EmptyMessageView(message: item.emptyMessage) {
                            withAnimation {
                                self.hideView = true
                            }
                        }
                    } else {
                        channelListView()
                    }
                } header: {
                    headerView()
                }
            }
            .onAppear {
                self.state.channelAssociationPublisher
                    .sink {
                        updateChannelsList($0)
                    }
                    .store(in: &subscriptions)
                Airship.contact.channelsListPublisher
                    .sink { state in
                        switch state {
                        case .failed:
                            self.registrationState = .failed
                        case .succeed(_):
                            self.registrationState = .succeed
#if canImport(AirshipCore)
                        @unknown default:
                            AirshipLogger.error("Unknown registration state")
#endif
                        }
                    }
                    .store(in: &subscriptions)
            }
            .padding(5)
        }
    }
    
    private func updateChannelsList(_ channelsList: [String: AssociatedChannel]) {
        switch self.item.registrationOptions {
        case .sms(_):
            self.channels = channelsList.values.filter { $0.channelType == .sms }
        case .email(_):
            self.channels = channelsList.values.filter { $0.channelType == .email }
        }
    }
    
    @ViewBuilder
    private func AddChannelPromptView() -> some View {
        if let view = self.item.addPrompt?.view {
            AddChannelView(
                item: view,
                registrationOptions: self.item.registrationOptions,
                state: self.$registrationState
            ) {
                self.disposable?.cancel()
            } onCancel: {
                self.disposable?.cancel()
            }
            .transition(.scale)
        }
    }
    
    @ViewBuilder
    private func RemoveChannelPromptView() -> some View {
        if let view = self.item.removePrompt {
            RemoveChannelPrompt(
                item: view,
                theme: self.theme.contactManagement) {
                    if let channel = self.selectedChannel {
                        Airship.contact.optOutChannel(channel.channelID)
                    }
                    self.disposable?.cancel()
                }
            
        }
    }
    
    private func headerView() -> some View {
        return HStack {
            VStack(alignment: .leading) {
                Text(self.item.display.title)
                    .font(.headline)
                if let subtitle = self.item.display.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                }
            }
            Spacer()
            Button {
                self.disposable = ChannelsListView.showModalView(
                    rootView: AddChannelPromptView(),
                    theme: self.theme.contactManagement
                )
                self.registrationState = .inProgress(false)
            } label: {
                Text(self.item.addPrompt?.button.text ?? "")
            }
            .optAccessibilityLabel(
                string: self.item.addPrompt?.button.contentDescription
            )
        }
    }
    
    private func channelListView() -> some View {
        ForEach(self.channels, id: \.self) { channel in
            VStack(alignment: .leading) {
                Divider()
                HStack {
                    Text(channel.channelID.mask(self.item.registrationOptions))
                    Spacer()
                    if let removePrompt = self.item.removePrompt {
                        LabeledButton(
                            item: removePrompt.button,
                            theme: self.theme.contactManagement
                        ) {
                            self.disposable = ChannelsListView.showModalView(
                                rootView: RemoveChannelPromptView(),
                                theme: self.theme.contactManagement
                            )
                            self.selectedChannel = channel
                        }
                    }
                }
                .padding(3)
            }
        }
    }
}

// MARK: Empty message view
private struct EmptyMessageView: View {
    
    static let padding = EdgeInsets(top: 0, leading: 25, bottom: 5, trailing: 0)
    
    // The empty message
    var message: String?
    
    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?
    
    var action: (()->())?
    
    public var body: some View {
        VStack(alignment: .leading) {
            Divider()
            /// Message
            Text(self.message ?? "")
                .textAppearance(
                    theme?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
                )
        }
        .transition(.scale)
        .padding(5)
    }
}

// MARK: Reprompt view
public struct RePromptView: View {
    
    public var item: PreferenceCenterConfig.ContactManagementItem.RepromptOptions
    
    public var registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?
    
    public var channel: AssociatedChannel
    
    /// The preference center theme
    public var theme: PreferenceCenterTheme.ContactManagement?
    
    @State
    private var selectedSender = PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo(
        senderId: "",
        placeHolderText: "",
        countryCode: "",
        displayName: ""
    )
    
    @State
    private var inputText = ""
    
    @State
    private var isValid = true
    
    @State
    private var startEditing = false
    
    @State
    private var disposable: AirshipMainActorCancellableBlock? = nil

    public init(
        item: PreferenceCenterConfig.ContactManagementItem.RepromptOptions,
        registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?,
        channel: AssociatedChannel,
        theme: PreferenceCenterTheme.ContactManagement? = nil
    ) {
        self.item = item
        self.registrationOptions = registrationOptions
        self.channel = channel
        self.theme = theme
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            /// Title
            Text(self.item.message)
                .textAppearance(
                    theme?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
                )
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                ChannelTextField(
                    registrationOptions: self.registrationOptions,
                    selectedSender: self.$selectedSender,
                    inputText: self.$inputText,
                    isValid: self.$isValid,
                    startEditing: self.$startEditing)
                .padding(EdgeInsets(top: 0, leading: 3, bottom: 0, trailing: 3))
                
                //Retry button
                LabeledButton(
                    item: self.item.button,
                    theme: self.theme) {
                        // TODO: Retry
                    }
            }
        }
        .onAppear {
            self.inputText = channel.channelID.deletePrefix("+44")
        }
    }
    
}

// MARK: Remove channel view
private struct RemoveChannelPrompt: View {
    
    var item: PreferenceCenterConfig.ContactManagementItem.RemoveChannel
    
    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?
    
    var optOutAction: (()->())?
    
    var body: some View {
        
        VStack() {
            /// Title
            Text(item.view.display.title)
                .textAppearance(
                    theme?.titleAppearance,
                    base: DefaultContactManagementSectionStyle.titleAppearance
                )
            
            /// Body
            if let body = item.view.display.body {
                Text(body)
                    .textAppearance(
                        theme?.subtitleAppearance,
                        base: DefaultContactManagementSectionStyle.subtitleAppearance
                    )
                    .multilineTextAlignment(.center)
            }
            
            /// Buttons
            HStack {
                if let optOutButton = item.view.acceptButton {
                    /// Opt out Button
                    LabeledButton(
                        item: optOutButton,
                        theme: self.theme,
                        action: optOutAction
                    )
                }
            }
            
            /// Footer
            if let footer = item.view.display.footer {
                Text(footer)
                    .textAppearance(
                        theme?.subtitleAppearance,
                        base: DefaultContactManagementSectionStyle.subtitleAppearance
                    )
            }
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

// MARK: Background
struct BackgroundShape: View {
    var color: Color
    var body: some View {
        Rectangle()
            .fill(color)
            .cornerRadius(10)
            .shadow(radius: 5)
    }
}

// MARK: Utils methods
fileprivate extension String {
    
    func mask(_ type: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions) -> String {
        switch type {
        case .email(_):
            return self.maskEmail
        case .sms(_):
            return self.maskPhoneNumber
        }
    }
    
    var maskEmail: String {
        let components = self.components(separatedBy: "@")
        return hideMidChars(components.first!) + "@" + components.last!
    }
    
    var maskPhoneNumber: String {
        return String(self.enumerated().map { index, char in
            return [self.count - 1, self.count - 2].contains(index) ?
            char : "*"
        })
    }
    
    private func hideMidChars(_ value: String) -> String {
        return String(value.enumerated().map { index, char in
            return [0, value.count, value.count].contains(index) ? char : "*"
        })
    }
    
    func deletePrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}

// MARK: Modal view
extension ChannelsListView {
    
    @MainActor
    static func showModalView(
        rootView: some View,
        theme: PreferenceCenterTheme.ContactManagement?
    ) -> AirshipMainActorCancellableBlock? {

        guard let scene = try? AirshipSceneManager.shared.lastActiveScene else {
            AirshipLogger.error("Unable to display, missing scene.")
            return nil
        }
        
        var window: UIWindow? = UIWindow(windowScene: scene)
        
        let disposable = AirshipMainActorCancellableBlock {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }
        
        let viewController = ModalCenterViewController(
            rootView: rootView,
            backgroundColor: .clear.withAlphaComponent(0.5)
        )
        
        window?.windowLevel = .alert
        window?.makeKeyAndVisible()
        window?.rootViewController = viewController
        
        return disposable
    }
}

private class ModalCenterViewController<Content>: UIHostingController<
Content
>
where Content: View {
    init(
        rootView: Content,
        backgroundColor: UIColor? = nil
    ) {
        super.init(rootView: rootView)
        if let backgroundColor = backgroundColor {
            self.view.backgroundColor = backgroundColor        }
    }
    
    @objc
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Preview
struct ChannelsListView_Previews: PreviewProvider {
    
    static var previews: some View {
        VStack {
            RePromptView(
                item: PreferenceCenterConfig.ContactManagementItem.RepromptOptions(
                    interval: 5,
                    message: "Failed to optin. Please try again",
                    button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Retry")),
                registrationOptions: .sms(PreferenceCenterConfig.ContactManagementItem.SmsRegistrationOption(senders: [
                    PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo(
                        senderId: "34",
                        placeHolderText: "Phone number",
                        countryCode: "+44",
                        displayName: "US")
                ])),
                channel: AssociatedChannel(
                    channelType: .sms,
                    channelID: "1233",
                    identifier: "+44256676",
                    registrationDate: Date()
                )
            )
        }
    }
}
