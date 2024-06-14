/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif


class ChannelListCellViewModel: ObservableObject {
    let channel: ContactChannel
    let pendingLabelModel: PreferenceCenterConfig.ContactManagementItem.PendingLabel?

    @Published
    internal var isPendingLabelShowing: Bool = false

    @Published
    internal var isResendShowing: Bool = false

    let onResend: () -> Void
    let onRemove: () -> Void
    let onDismiss: () -> Void

    private let pendingLabelHideDelaySeconds: Double = 30
    private var resendLabelHideDelaySeconds: Double { Double(pendingLabelModel?.intervalInSeconds ?? 15) }

    private var hidePendingLabelTask:Task<Void, Never>?
    private var hideResendButtonTask:Task<Void, Never>?

    init(channel: ContactChannel,
         pendingLabelModel: PreferenceCenterConfig.ContactManagementItem.PendingLabel?,
         onResend: @escaping () -> (),
         onRemove: @escaping () -> Void,
         onDismiss: @escaping () -> Void) {
        self.channel = channel
        self.pendingLabelModel = pendingLabelModel
        self.onResend = onResend
        self.onRemove = onRemove
        self.onDismiss = onDismiss

        initializePendingLabel()
    }

    private func initializePendingLabel() {
        temporarilyShowPendingLabel()

        /// If we are initializing the cell as a pending cell, assume it's recent
        /// hide the resend button for the interval set on the pending label model
        if !channel.isRegistered {
            temporarilyHideResend()
        } else {
            isResendShowing = true
        }
    }

    func temporarilyShowPendingLabel() {
        withAnimation {
            isPendingLabelShowing = true
        }

        hidePendingLabelTask?.cancel()
        hidePendingLabelTask = Task { @MainActor [weak self] in
            guard let self = self, !Task.isCancelled else { return}

            try? await Task.sleep(nanoseconds: UInt64(pendingLabelHideDelaySeconds * 1_000_000_000))

            guard !Task.isCancelled else { return}

            withAnimation {
                self.isPendingLabelShowing = false
            }
        }
    }

    /// Used to temporarily hide the resend button for the interval provided by the model, also used to hide the button after each tap
    func temporarilyHideResend() {
        withAnimation {
            isResendShowing = false
        }

        hideResendButtonTask?.cancel()
        hideResendButtonTask = Task { @MainActor [weak self] in
            guard let self = self, !Task.isCancelled else { return}

            try? await Task.sleep(nanoseconds: UInt64(resendLabelHideDelaySeconds * 1_000_000_000))

            guard !Task.isCancelled else { return}

            withAnimation {
                self.isResendShowing = true
            }
        }
    }
}

struct ChannelListViewCell: View {
    @StateObject private var viewModel: ChannelListCellViewModel

    @Environment(\.airshipPreferenceCenterTheme)
    private var theme: PreferenceCenterTheme

    init(viewModel: ChannelListCellViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @ViewBuilder
    private var pendingLabelView: some View {
        HStack(spacing: 8) {
            if let pendingText = viewModel.pendingLabelModel?.message {
                Text(pendingText).textAppearance(
                    theme.contactManagement?.listSubtitleAppearance,
                    base: DefaultContactManagementSectionStyle.listSubtitleAppearance
                )
            }

            if viewModel.isResendShowing {
                resendButton
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var resendButton: some View {
        if let resendTitle = viewModel.pendingLabelModel?.button.text {
            Button {
                viewModel.temporarilyHideResend()
                viewModel.onResend()
            } label: {
                Text(resendTitle).textAppearance(
                    theme.contactManagement?.listSubtitleAppearance,
                    base: DefaultContactManagementSectionStyle.resendButtonTitleAppearance
                )
            }
        }
    }

    private var trashButton: some View {
        Button(action: {
            viewModel.onRemove()
        }) {
            Image(systemName: "trash")
                .foregroundColor(theme.contactManagement?.titleAppearance?.color ?? .primary)
        }
    }

    @ViewBuilder
    private func makeCellLabel(iconSystemName: String, labelText: String) -> some View {
        HStack {
            Image(systemName: iconSystemName)
                .font(.system(size: 16))
                .foregroundColor(theme.contactManagement?.titleAppearance?.color ?? DefaultColors.secondaryText)
            Text(labelText).textAppearance(
                theme.contactManagement?.listSubtitleAppearance,
                base: DefaultContactManagementSectionStyle.listTitleAppearance
            )
        }
    }

    @ViewBuilder
    private func makeErrorLabel(labelText: String) -> some View {
        ErrorLabel(message: labelText, theme: self.theme.contactManagement)
    }

    @ViewBuilder
    private func makePendingLabel(channel: ContactChannel) -> some View {
        if (channel.isRegistered) {
            let isOptedIn = channel.isOptedIn
            if viewModel.isPendingLabelShowing, !isOptedIn {
                pendingLabelView
            }
        } else {
            if viewModel.isPendingLabelShowing {
                pendingLabelView
            }
        }

    }

    @ViewBuilder
    private func makeCell(channel: ContactChannel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let cellText = channel.maskedAddress.replacingAsterisksWithBullets()
            if channel.channelType == .email {
                makeCellLabel(iconSystemName: "envelope", labelText: cellText)
            } else {
                makeCellLabel(iconSystemName: "phone", labelText: cellText)
            }

            makePendingLabel(channel: channel)
        }
    }

    private var cellBody: some View {
        VStack(alignment: .leading) {
            Divider()
            HStack {
                makeCell(channel: viewModel.channel)
                Spacer()
                trashButton
            }
            .padding(3)
        }
    }

    var body: some View {
        cellBody
    }
}


extension ContactChannel {
    var isOptedIn: Bool {
        switch (self) {
        case .email(let email):
            switch(email) {
            case .pending(_): return false
            case .registered(let info):
                guard let optedOut = info.commercialOptedOut else {
                    return info.commercialOptedIn != nil
                }
                return info.commercialOptedIn?.compare(optedOut) == .orderedDescending /// Make sure optedIn date is after opt out date if both exist
#if canImport(AirshipCore)
            @unknown default:
                return false
#endif
            }
        case .sms(let sms):
            switch(sms) {
            case .pending(_): return false
            case .registered(let info): return info.isOptIn
#if canImport(AirshipCore)
            @unknown default:
                return false
#endif
            }
#if canImport(AirshipCore)
        @unknown default:
            return false
#endif
        }
    }
}
