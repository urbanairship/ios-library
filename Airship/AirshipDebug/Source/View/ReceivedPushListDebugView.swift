/* Copyright Airship and Contributors */

import Combine
import SwiftUI

#if canImport(AirshipCore)
    import AirshipCore
#elseif canImport(AirshipKit)
    import AirshipKit
#endif

struct ReceivedPushListDebugView: View {

    @StateObject
    private var viewModel = ViewModel()

    var body: some View {
        Form {
            Section(header: Text("")) {
                List(self.viewModel.pushNotifications, id: \.self) { push in
                    NavigationLink(destination: PushDetailDebugView(push: push))
                    {
                        HStack {
                            Text(push.alert ?? "Silent Push".localized())
                            Text(push.pushID)
                        }
                    }
                }
            }
        }
        .navigationTitle("Push Notifications".localized())
    }

    class ViewModel: ObservableObject {
        @Published private(set) var pushNotifications: [PushNotification] = []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.refreshPush()
                self.cancellable = AirshipDebugManager.shared
                    .pushNotifiacitonReceivedPublisher
                    .sink { [weak self] _ in
                        self?.refreshPush()
                    }
            }
        }

        private func refreshPush() {
            Task {
                let notifications = await AirshipDebugManager.shared
                    .pushNotifications()
                await MainActor.run {
                    self.pushNotifications = notifications
                }
            }
        }
    }
}

private struct PushDetailDebugView: View {
    let push: PushNotification

    @ViewBuilder
    var body: some View {
        Form {
            Section(header: Text("Push details".localized())) {
                Text(push.description)
            }
        }
        .navigationTitle(self.push.alert ?? "Silent Push".localized())
    }
}
