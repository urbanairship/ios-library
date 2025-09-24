/* Copyright Airship and Contributors */

import SwiftUI
import Combine
import AirshipCore

struct AirshipDebugPushDetailsView: View {

    @StateObject
    private var viewModel: ViewModel

    init(identifier: String) {
        _viewModel = .init(wrappedValue: .init(identifier: identifier))
    }

    var body: some View {
        if let push = viewModel.pushNotification {
            AirshipJSONDetailsView(payload: push.payload, title: push.alert ?? "Silent Push".localized())
        } else {
            ProgressView()
        }
    }


    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var pushNotification: PushNotification?

        init(identifier: String) {
            Task { @MainActor [weak self] in
                self?.pushNotification = await Airship.internalDebugManager.pushNotifications().first(where: {
                    $0.pushID == identifier
                })
            }
        }
    }
}
