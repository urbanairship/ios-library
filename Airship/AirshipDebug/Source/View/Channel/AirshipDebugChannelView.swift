/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AirshipDebugChannelView: View {

    @State
    private var toastMessage: AirshipToast.Message? = nil

    @StateObject
    private var viewModel = ViewModel()

    var body: some View {
        Form {
            let channelID = viewModel.channelID
            CommonItems.infoRow(
                title: "Channel ID".localized(),
                value: channelID,
                onTap: { copyChananelId(channelID) }
            )

            CommonItems.navigationLink(
                title: "Tags".localized(),
                route: .channelSub(.tags)
            )

            CommonItems.navigationLink(
                title: "Tag Groups".localized(),
                route: .channelSub(.tagGroups)
            )

            CommonItems.navigationLink(
                title: "Attributes".localized(),
                route: .channelSub(.attributes)
            )

            CommonItems.navigationLink(
                title: "Subscription Lists".localized(),
                route: .channelSub(.subscriptionLists)
            )
        }
        .toastable($toastMessage)
        .navigationTitle("Channel".localized())
    }
    
    private func copyChananelId(_ channelId: String?) {
        guard let channelId else { return }
        
        channelId.pastleboard()
        self.toastMessage = .init(text: "Channel ID copied to clipboard")
    }


    @MainActor
    fileprivate final class ViewModel: ObservableObject {
        @Published
        var channelID: String?

        private var task: Task<Void, Never>? = nil

        @MainActor
        init() {
            self.task = Task { [weak self] in
                await Airship.waitForReady()

                for await _ in Airship.channel.identifierUpdates {
                    self?.updateChannelID()
                }
            }
            updateChannelID()
        }

        deinit {
            task?.cancel()
        }

        private func updateChannelID() {
            guard Airship.isFlying else { return }
            if self.channelID != Airship.channel.identifier {
                channelID = Airship.channel.identifier
            }
        }
    }
}

#Preview {
    AirshipDebugChannelView()
}
