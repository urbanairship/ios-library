/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

// MARK: Channel list view for a given section
struct ChannelListView: View {
    let item: PreferenceCenterConfig.ContactManagementItem

    @ObservedObject
    var state: PreferenceCenterState

    @Environment(\.airshipPreferenceCenterTheme)
    private var theme: PreferenceCenterTheme

    @State
    private var hideView: Bool = false

    @State
    private var disposable: AirshipMainActorCancellableBlock?

    @State
    private var subscriptions: Set<AnyCancellable> = []

    @State
    private var selectedChannel: ContactChannel?

    @State
    private var pendingShowFlags:[String: Bool] = [:]
    private func pendingFlagsBinding(for key: String) -> Binding<Bool> {
        return .init(
            get: { self.pendingShowFlags[key, default: false] },
            set: { self.pendingShowFlags[key] = $0 })
    }

    @State
    private var resendShowFlags:[String: Bool] = [:]
    private func resendFlagsBinding(for key: String) -> Binding<Bool> {
        return .init(
            get: { self.resendShowFlags[key, default: true] },
            set: { self.resendShowFlags[key] = $0 })
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
                        Airship.contact.disassociateChannel(channel)
                        self.selectedChannel = nil
                    }
                    dismissPrompt()
                }
        }
    }

    @ViewBuilder
    private func makeAddButton(model: PreferenceCenterConfig.ContactManagementItem.LabeledButton) -> some View {
        LabeledButton(
            type: .outlineType,
            item: model,
            theme: self.theme.contactManagement
        ) {
            self.disposable = ChannelListView.showModalView(
                rootView: addChannelPromptView,
                theme: self.theme.contactManagement
            )
        }
    }

    private func pendingLabelModelForType(type: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions) -> PreferenceCenterConfig.ContactManagementItem.PendingLabel? {
        switch type {
        case .sms(let options):
            return options.pendingLabel
        case .email(let options):
            return options.pendingLabel
        }
    }

    @ViewBuilder
    private var headerTitleView: some View {
        Text(self.item.display.title)
            .textAppearance(
                theme.contactManagement?.titleAppearance,
                base: DefaultContactManagementSectionStyle.titleAppearance
            )
    }

    @ViewBuilder
    private var headerSubtitleView: some View {
        if let subtitle = self.item.display.subtitle {
            Text(subtitle)
                .textAppearance(
                    theme.contactManagement?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
                )
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                headerTitleView
                headerSubtitleView
            }
            Spacer()
        }
    }

    private func resend(_ channel: ContactChannel) {
        self.disposable = ChannelListView.showModalView(
            rootView: resendPromptView,
            theme: self.theme.contactManagement
        )
        self.selectedChannel = channel
    }

    private func remove(_ channel: ContactChannel) {
        self.disposable = ChannelListView.showModalView(
            rootView: removePromptView,
            theme: self.theme.contactManagement
        )
        self.selectedChannel = channel
    }

    @ViewBuilder
    private var channelListView:some View {
        ForEach(Array(self.$state.channelsList.wrappedValue.filter(with: self.item.platform.channelType)), id: \.self) { channel in
            ChannelListViewCell(viewModel: ChannelListCellViewModel(channel: channel,
                                                                    pendingLabelModel: pendingLabelModelForType(type: item.registrationOptions),
                                                                    onResend: {
                resend(channel)
            }, onRemove: {
                remove(channel)
            }, onDismiss: dismissPrompt))
        }
    }

    internal init(item: PreferenceCenterConfig.ContactManagementItem, state: PreferenceCenterState) {
        self.item = item
        self.state = state
    }

    var body: some View {
        if !self.hideView {
            VStack {
                Section {
                    VStack(alignment: .leading) {
                        if self.$state.channelsList.wrappedValue.filter(with: self.item.platform.channelType).isEmpty {
                            EmptySectionLabel(label: item.emptyLabel) {
                                withAnimation {
                                    self.hideView = true
                                }
                            }
                        } else {
                            channelListView
                        }
                        if let model = self.item.addPrompt?.button {
                            makeAddButton(model: model)
                        }
                    }
                } header: {
                    headerView
                }
            }
            .padding(.bottom, 8)
        }
    }
}

extension ChannelListView {
    // MARK: Prompt functions

    private func registerSMS(msisdn: String, sender: String) {
        let options = SMSRegistrationOptions.optIn(
            senderID: sender
        )

        Airship.contact.registerSMS(msisdn, options: options)

        dismissPrompt()
    }

    private func registerEmail(email: String) {
        let options = EmailRegistrationOptions.options(properties: nil, doubleOptIn: true)

        Airship.contact.registerEmail(email, options: options)

        dismissPrompt()
    }

    // MARK: Prompt Views

    @ViewBuilder
    private var resendPromptView: some View {
        /// When we have submitted successfully users see a follow up prompt telling them to check their messaging app, email inbox, etc.
        ResultPromptView(
            item: pendingLabelModelForType(type: item.registrationOptions)?.resendSuccessPrompt,
            theme: theme.contactManagement
        ) {
            if let channel = self.selectedChannel {
                Airship.contact.resend(channel)
                self.selectedChannel = nil
            }
            dismissPrompt()
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var addChannelPromptView: some View {
        if let view = self.item.addPrompt?.view {
            let viewModel = AddChannelPromptViewModel(item: view,
                                                      theme: self.theme.contactManagement,
                                                      registrationOptions: self.item.registrationOptions,
                                                      onCancel: dismissPrompt,
                                                      onRegisterSMS: registerSMS,
                                                      onRegisterEmail: registerEmail)


            AddChannelPromptView(viewModel: viewModel)
            .transition(.opacity)
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

extension PreferenceCenterConfig.ContactManagementItem.Platform {
    var channelType: ChannelType {
        switch self {
        case .sms: return .sms
        case .email: return .email
        }
    }
}
