/* Copyright Urban Airship and Contributors */

import AirshipCore
import Combine
import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published
    var selectedTab: SampleTabs = .home
    
    @Published
    var homeDestination: HomeDestination? = nil
    
    @Published
    var unreadCount = 0
    
    @Published
    var toastMessage: Toast.Message?

    
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        if Airship.isFlying {
//            MessageCenter.shared.inbox.unreadCountPublisher
//                .receive(on: RunLoop.main)
//                .sink { unreadCount in
//                    self.unreadCount = unreadCount
//                }
//                .store(in: &self.subscriptions)
        }
    }
}

enum SampleTabs: Hashable {
    case home
    case messageCenter
    case preferenceCenter
}

enum HomeDestination: Hashable {
    case namedUser
}
