/* Copyright Airship and Contributors */

import Combine
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct ReceivedPushListDebugView: View {

    @StateObject
    private var viewModel = ViewModel()

    public init() {}
    
    public var body: some View {
        Form {
            List(self.viewModel.pushNotifications, id: \.self) { push in
                NavigationLink(destination: AirshipJSONDetailsView(
                    payload: AirshipJSON.wrapSafe(push.description),
                    title: push.alert ?? "Silent Push".localized()
                ))
                {
                    HStack {
                        Text(push.alert ?? "Silent Push".localized())
                        Text(push.pushID)
                    }
                }
            }
        }
        .navigationTitle("Push Notifications".localized())
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var pushNotifications: [PushNotification] = []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.refreshPush()
                self.cancellable = Airship.debugManager
                    .pushNotifiacitonReceivedPublisher
                    .sink { [weak self] _ in
                        self?.refreshPush()
                    }
            }
        }

        private func refreshPush() {
            Task {
                let notifications = await Airship.debugManager
                    .pushNotifications()
                await MainActor.run {
                    self.pushNotifications = notifications
                }
            }
        }
    }
}

#Preview {
    ReceivedPushListDebugView()
}
