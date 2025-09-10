/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

import Combine

@MainActor
class ChannelListCellViewModel: ObservableObject {
    let channel: ContactChannel
    let pendingLabelModel: PreferenceCenterConfig.ContactManagementItem.PendingLabel?

    @Published
    internal var isPendingLabelShowing: Bool = false

    @Published
    internal var isResendShowing: Bool = false

    let onResend: () -> Void
    let onRemove: () -> Void

    private var resendLabelHideDelaySeconds: Double { Double(pendingLabelModel?.intervalInSeconds ?? 15) }

    private var hidePendingLabelTask:Task<Void, Never>?
    private var hideResendButtonTask:Task<Void, Never>?

    init(channel: ContactChannel,
         pendingLabelModel: PreferenceCenterConfig.ContactManagementItem.PendingLabel?,
         onResend: @escaping () -> (),
         onRemove: @escaping () -> Void
    ) {
        self.channel = channel
        self.pendingLabelModel = pendingLabelModel
        self.onResend = onResend
        self.onRemove = onRemove
        initializePendingLabel()
    }

    private func initializePendingLabel() {
        let isOptedIn = channel.isOptedIn

        if isOptedIn {
            withAnimation {
                isPendingLabelShowing = false
                isResendShowing = false
            }
        } else {
            withAnimation {
                isPendingLabelShowing = true
            }
            temporarilyHideResend()
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

            guard !Task.isCancelled, !channel.isOptedIn else { return}

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

    @Environment(\.colorScheme)
    private var colorScheme

    init(viewModel: ChannelListCellViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @ViewBuilder
    private var pendingLabelView: some View {
        HStack(spacing: PreferenceCenterDefaults.smallPadding) {
            if let pendingText = viewModel.pendingLabelModel?.message {
                Text(pendingText).textAppearance(
                    theme.contactManagement?.listSubtitleAppearance,
                    base: PreferenceCenterDefaults.channelListItemSubtitleAppearance,
                    colorScheme: colorScheme
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
                    base: PreferenceCenterDefaults.resendButtonTitleAppearance,
                    colorScheme: colorScheme
                )
            }
        }
    }

    private var trashButton: some View {
        Button(action: {
            viewModel.onRemove()
        }) {
            Image(systemName: "trash")
                .foregroundColor(
                    theme.contactManagement?.titleAppearance?.color ?? .primary
                )
        }
    }

    @ViewBuilder
    private func makeCellLabel(iconSystemName: String, labelText: String) -> some View {
        SwiftUI.Label {
            Text(labelText).textAppearance(
                theme.contactManagement?.listSubtitleAppearance,
                base: PreferenceCenterDefaults.channelListItemTitleAppearance,
                colorScheme: colorScheme
            )
            .lineLimit(1)
            .truncationMode(.middle)
        } icon: {
            Image(systemName: iconSystemName)
                .textAppearance(
                    theme.contactManagement?.listSubtitleAppearance,
                    base: PreferenceCenterDefaults.channelListItemTitleAppearance,
                    colorScheme: colorScheme
                )
        }
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
        VStack(alignment: .leading) {
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
            HStack(alignment: .top) {
                makeCell(channel: viewModel.channel)
                Spacer()
                trashButton
            }
        }
        .padding(PreferenceCenterDefaults.smallPadding)
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
