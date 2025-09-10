/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

struct ChannelListView: View {
    // MARK: - Constants
    private enum Layout {
        static let presentationDetentHeight: CGFloat = 0.5 // medium detent as fraction
    }

    // MARK: - Environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.airshipPreferenceCenterTheme) private var theme: PreferenceCenterTheme

    // MARK: - Properties
    let item: PreferenceCenterConfig.ContactManagementItem
    @ObservedObject var state: PreferenceCenterState

    // MARK: - State
    @State private var selectedChannel: ContactChannel?
    @State private var showAddChannelSheet = false
    @State private var showRemoveChannelAlert = false
    @State private var showResendSuccessAlert = false

    // MARK: - Computed Properties
    private var channels: [ContactChannel] {
        state.channelsList.filter(with: item.platform.channelType)
    }

    private var isChannelListEmpty: Bool {
        channels.isEmpty
    }

    private var removeAlertTitle: String {
        item.removeChannel?.view.display.title ?? "Remove Channel"
    }

    private var resendAlertTitle: String {
        pendingLabelModel?.resendSuccessPrompt?.title ?? "Verification Sent"
    }

    private var pendingLabelModel: PreferenceCenterConfig.ContactManagementItem.PendingLabel? {
        switch item.platform {
        case .sms(let options):
            return options.pendingLabel
        case .email(let options):
            return options.pendingLabel
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading) {
            Section {
                VStack(alignment: .leading) {
                    if isChannelListEmpty {
                        EmptySectionLabel(label: item.emptyMessage)
                    } else {
                        channelListView
                    }

                    if let buttonModel = item.addChannel?.button {
                        addChannelButton(model: buttonModel)
                    }
                }
            } header: {
                headerView
            }
        }
        .sheet(isPresented: $showAddChannelSheet) {
            addChannelPromptView
                .airshipApplyIf(true) { view in
                    if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                        view.presentationDetents([.medium])
                    }
                }
        }
        .alert(
            removeAlertTitle,
            isPresented: $showRemoveChannelAlert,
            presenting: selectedChannel
        ) { channel in
            removeAlertButtons(for: channel)
        } message: { _ in
            removeAlertMessage
        }
        .alert(
            resendAlertTitle,
            isPresented: $showResendSuccessAlert,
            presenting: selectedChannel
        ) { _ in
            resendAlertButton
        } message: { _ in
            resendAlertMessage
        }
    }

    // MARK: - View Components
    @ViewBuilder
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.display.title)
                    .textAppearance(
                        theme.contactManagement?.titleAppearance,
                        base: PreferenceCenterDefaults.sectionTitleAppearance,
                        colorScheme: colorScheme
                    )
                    .accessibilityAddTraits(.isHeader)

                if let subtitle = item.display.subtitle {
                    Text(subtitle)
                        .textAppearance(
                            theme.contactManagement?.subtitleAppearance,
                            base: PreferenceCenterDefaults.sectionSubtitleAppearance,
                            colorScheme: colorScheme
                        )
                }
            }
            Spacer()
        }
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var channelListView: some View {
        ForEach(channels, id: \.self) { channel in
            ChannelListViewCell(
                viewModel: ChannelListCellViewModel(
                    channel: channel,
                    pendingLabelModel: pendingLabelModel,
                    onResend: { resend(channel) },
                    onRemove: { remove(channel) }
                )
            )
#if os(tvOS)
            .focusSection()
#endif
        }
    }

    @ViewBuilder
    private func addChannelButton(model: PreferenceCenterConfig.ContactManagementItem.LabeledButton) -> some View {
        HStack {
            Button {
                if item.addChannel?.view != nil {
                    showAddChannelSheet = true
                }
            } label: {
                Text(model.text)
                    .textAppearance(
                        theme.contactManagement?.buttonLabelAppearance,
                        colorScheme: colorScheme
                    )
            }
#if !os(tvOS)
            .controlSize(.regular)
#endif


            Spacer()
        }
#if os(tvOS)
        .focusSection()
#endif
    }

    @ViewBuilder
    private var addChannelPromptView: some View {
        if let view = item.addChannel?.view {
            AddChannelPromptView(
                viewModel: AddChannelPromptViewModel(
                    item: view,
                    theme: theme.contactManagement,
                    registrationOptions: item.platform,
                    onCancel: { showAddChannelSheet = false },
                    onRegisterSMS: registerSMS,
                    onRegisterEmail: registerEmail
                )
            )
        }
    }

    // MARK: - Alert Components
    @ViewBuilder
    private func removeAlertButtons(for channel: ContactChannel) -> some View {
        Button(role: .destructive) {
            AirshipLogger.info("Removing channel: \(channel.channelType)")
            Airship.contact.disassociateChannel(channel)
            selectedChannel = nil
        } label: {
            Text(item.removeChannel?.view.submitButton?.text ?? "Remove")
        }

        Button(role: .cancel) {
            selectedChannel = nil
        } label: {
            Text(item.removeChannel?.view.cancelButton?.text ?? "Cancel")
        }
    }

    @ViewBuilder
    private var removeAlertMessage: some View {
        if let body = item.removeChannel?.view.display.body {
            Text(body)
        }
    }

    @ViewBuilder
    private var resendAlertButton: some View {
        Button {
            selectedChannel = nil
        } label: {
            Text(pendingLabelModel?.resendSuccessPrompt?.button.text ?? "OK")
        }
    }

    @ViewBuilder
    private var resendAlertMessage: some View {
        if let body = pendingLabelModel?.resendSuccessPrompt?.body {
            Text(body)
        }
    }

    // MARK: - Actions
    private func resend(_ channel: ContactChannel) {
        selectedChannel = channel
        Airship.contact.resend(channel)
        AirshipLogger.info("Resending verification for channel: \(channel.channelType)")
        showResendSuccessAlert = true
    }

    private func remove(_ channel: ContactChannel) {
        selectedChannel = channel
        AirshipLogger.info("Showing remove confirmation for channel: \(channel.channelType)")
        showRemoveChannelAlert = true
    }

    private func registerSMS(msisdn: String, sender: String) {
        let options = SMSRegistrationOptions.optIn(senderID: sender)
        Airship.contact.registerSMS(msisdn, options: options)
        AirshipLogger.info("Registered SMS channel: \(msisdn)")
    }

    private func registerEmail(email: String) {
        let options = EmailRegistrationOptions.options(properties: nil, doubleOptIn: true)
        Airship.contact.registerEmail(email, options: options)
        AirshipLogger.info("Registered email channel: \(email)")
    }
}

// MARK: - Extensions
extension PreferenceCenterConfig.ContactManagementItem.Platform {
    var channelType: ChannelType {
        switch self {
        case .sms: return .sms
        case .email: return .email
        }
    }
}
