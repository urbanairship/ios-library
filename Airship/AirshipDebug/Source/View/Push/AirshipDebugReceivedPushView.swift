/* Copyright Airship and Contributors */

import Combine
import SwiftUI
import AirshipCore

struct AirshipDebugReceivedPushView: View {

    @StateObject
    private var viewModel = ViewModel()


    var body: some View {
        Form {
            ForEach(self.viewModel.pushNotifications, id: \.self) { push in
                CommonItems.navigationLink(
                    title: push.alert ?? "Silent Push".localized(),
                    route: .pushSub(.pushDetails(identifier: push.pushID))
                )
            }
        }
        .navigationTitle("Received Notifications".localized())
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var pushNotifications: [PushNotification] = []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.refreshPush()
                self.cancellable = Airship.internalDebugManager
                    .pushNotificationReceivedPublisher
                    .sink { [weak self] _ in
                        self?.refreshPush()
                    }
            }
        }

        private func refreshPush() {
            Task { @MainActor in
                self.pushNotifications = await Airship.internalDebugManager.pushNotifications()
            }
        }
    }
}

#Preview {
    AirshipDebugReceivedPushView()
}
