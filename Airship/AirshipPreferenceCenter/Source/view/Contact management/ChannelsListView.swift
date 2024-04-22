/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

// MARK: Channel list view
public struct ChannelsListView: View {
    
    public let item: PreferenceCenterConfig.ContactManagementItem

    @ObservedObject
    public var state: PreferenceCenterState
    
    @Environment(\.airshipPreferenceCenterTheme)
    private var theme: PreferenceCenterTheme
    
    private var channels: Binding<[AssociatedChannel]>
    
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
        state: PreferenceCenterState,
        channels: Binding<[AssociatedChannel]>
    ) {
        self.item = item
        self.state = state
        self.channels = channels
    }

    public var body: some View {
        if !self.hideView {
            VStack {
                Section {
                    VStack(alignment: .leading) {
                        if self.channels.wrappedValue.isEmpty {
                            EmptySectionLabel(label: item.emptyLabel) {
                                withAnimation {
                                    self.hideView = true
                                }
                            }
                        } else {
                            channelListView()
                        }
                        if let model = self.item.addPrompt?.button {
                            LabeledButton(
                                type: .outlineType,
                                item: model,
                                theme: self.theme.contactManagement
                            ) {
                                self.disposable = ChannelsListView.showModalView(
                                    rootView: addChannelPromptView,
                                    theme: self.theme.contactManagement
                                )
                            }
                        }
                    }
                } header: {
                    HStack {
                        headerView
                        Spacer()
                    }
                }
            }
            .onAppear {
                
                self.state.channelAssociationPublisher
                    .sink {
                        self.channels.wrappedValue = $0.filter(with: self.item.platform.channelType)
                    }
                    .store(in: &subscriptions)
                
                Airship.contact.channelRegistrationEditPublisher
                    .sink { state in
                        switch state {
                        case .failed:
                            /// TODO: Update state of the listing to show items that didn't complete
                            break
                        case .succeed(_):
                            /// TODO:  Update state of the listing to show items that completed
                            break
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

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading) {
            Text(self.item.display.title)
                .font(.headline)
            if let subtitle = self.item.display.subtitle {
                Text(subtitle)
                    .font(.subheadline)
            }
        }
    }

    private func channelListView() -> some View {
        ForEach(self.channels.wrappedValue, id: \.self) { channel in
            VStack(alignment: .leading) {
                Divider()
                HStack {
                    if case .sms(let associatedChannel) = channel {
                        Text(associatedChannel.msisdn)
                    } else if case .email(let associatedChannel) = channel {
                        Text(associatedChannel.address)
                    }
                    
                    Spacer()
                    if let removePrompt = self.item.removePrompt {
                        LabeledButton(
                            item: removePrompt.button,
                            theme: self.theme.contactManagement
                        ) {
                            self.disposable = ChannelsListView.showModalView(
                                rootView: removePromptView,
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

extension ChannelsListView {
    // MARK: Prompt Views

    @ViewBuilder
    private var addChannelPromptView: some View {
        if let view = self.item.addPrompt?.view {
            AddChannelPromptView(viewModel: AddChannelPromptViewModel(item: view,
                                                                      theme: self.theme.contactManagement,
                                                                      registrationOptions: self.item.registrationOptions) {
                /// onCancel
                dismissPrompt()
            } onSubmit: {
                dismissPrompt()
            })
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var removePromptView: some View {
        if let view = self.item.removePrompt {
            RemoveChannelPromptView(
                item: view,
                theme: self.theme.contactManagement) {
                    dismissPrompt()
                } optOutAction: {
                    if let channel = self.selectedChannel {
                        if case .sms(let associatedChannel) = channel {
                            Airship.contact.optOutChannel(associatedChannel.channelID)
                        } else if case .email(let associatedChannel) = channel {
                            Airship.contact.optOutChannel(associatedChannel.channelID)
                        }
                    }
                    dismissPrompt()
                }
        }
    }

    /// Pretty sure we use this extra window because creating the shadow view in the way we like is a pain since this isn't the top level view
    /// Can probably improve on this and keep this more self-contained.
    @MainActor
    static func showModalView(
        rootView: some View,
        theme: PreferenceCenterTheme.ContactManagement?
    ) -> AirshipMainActorCancellableBlock? {

        guard let scene = try? AirshipSceneManager.shared.lastActiveScene else {
            AirshipLogger.error("Unable to display, missing scene.")
            return nil
        }
        
        let window: UIWindow? = UIWindow(windowScene: scene)

        let disposable = AirshipMainActorCancellableBlock {
            DispatchQueue.main.async {
                window?.animateOut()
            }
        }
        
        let viewController = ChannelListViewHostingController(
            rootView: rootView,
            backgroundColor: .clear.withAlphaComponent(0.5)
        )

        window?.rootViewController = viewController
        window?.alpha = 0
        window?.animateIn()

        return disposable
    }

    private func dismissPrompt() {
        self.disposable?.cancel()
    }
}

private extension UIWindow {

    static func makeModalReadyWindow(
        scene: UIWindowScene
    ) -> UIWindow {
        let window: UIWindow = UIWindow(windowScene: scene)
        window.accessibilityViewIsModal = false
        window.alpha = 0
        window.makeKeyAndVisible()
        window.isUserInteractionEnabled = false

        return window
    }

    func addRootController<T: UIViewController>(
        _ viewController: T?
    ) {
        viewController?.modalPresentationStyle = UIModalPresentationStyle.automatic
        viewController?.view.isUserInteractionEnabled = true

        if let viewController = viewController,
           let rootController = self.rootViewController
        {
            rootController.addChild(viewController)
            viewController.didMove(toParent: rootController)
            rootController.view.addSubview(viewController.view)
        }

        self.isUserInteractionEnabled = true
    }

    func animateIn() {
        self.windowLevel = .alert
        self.makeKeyAndVisible()
        self.isUserInteractionEnabled = true

        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 1
            },
            completion: { _ in
            }
        )
    }

    func animateOut() {
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 0
            },
            completion: { _ in
                self.isHidden = true
                self.isUserInteractionEnabled = false
                self.removeFromSuperview()
            }
        )
    }
}

extension PreferenceCenterConfig.ContactManagementItem.Platform {
    var channelType: ChannelType {
        switch self {
        case .sms: return .sms
        case .email: return .email
        }
    }
}

// MARK: Preview
//struct ChannelsListView_Previews: PreviewProvider {
//    
//    static var previews: some View {
//        VStack {
//            RePromptView(
//                item: PreferenceCenterConfig.ContactManagementItem.RepromptOptions(
//                    interval: 5,
//                    message: "Failed to optin. Please try again",
//                    button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Retry")),
//                registrationOptions: .sms(PreferenceCenterConfig.ContactManagementItem.SmsRegistrationOption(senders: [
//                    PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo(
//                        senderId: "34",
//                        placeholderText: "Phone number",
//                        countryCode: "+44",
//                        displayName: "US")
//                ])),
//                channel: .sms(
//                    SMSAssociatedChannel(
//                        channelID: "1233",
//                        msisdn: "*******6676",
//                        optIn: true
//                    )
//                )
//            )
//        }
//    }
//}
