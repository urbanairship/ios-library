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
                NavigationLink(
                    destination: AirshipJSONDetailsView(
                        payload: push.payload,
                        title: push.alert ?? "Silent Push".localized()
                    )
                ) {
                    VStack(alignment: .leading) {
                        Text(push.alert ?? "Silent Push".localized())
                        Text(push.pushID).font(.subheadline)
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
                    .pushNotificationReceivedPublisher
                    .sink { [weak self] _ in
                        self?.refreshPush()
                    }
            }
        }

        private func refreshPush() {
            Task { @MainActor in
                self.pushNotifications = await Airship.debugManager.pushNotifications()
            }
        }
    }
}
