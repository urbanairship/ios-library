/* Copyright Urban Airship and Contributors */

import AirshipCore
import AirshipMessageCenter
import Combine
import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    let messageCenterController = MessageCenterController()
    
    @Published
    var selectedTab: SampleTabs = .home
    
    @Published
    var homeDestination: HomeDestination? = nil
    
    @Published
    var unreadCount = 0
    
    @Published
    var toastMessage: Toast.Message?
    
    @Published
    var status = MessageCenterState.notVisible
    
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        if Airship.isFlying {
            MessageCenter.shared.inbox.unreadCountPublisher
                .receive(on: RunLoop.main)
                .sink { unreadCount in
                    self.unreadCount = unreadCount
                }
                .store(in: &self.subscriptions)
            
            MessageCenter.shared.controller = messageCenterController
            MessageCenter.shared.controller.statePublisher
                .receive(on: RunLoop.main)
                .sink { status in
                    self.status = status
                }
                .store(in: &self.subscriptions)
        }
        
    }
}

enum SampleTabs: Hashable {
    case home
    case messageCenter
    case preferenceCenter
#if canImport(AirshipDebug)
    case debug
#endif
}

enum HomeDestination: Hashable {
    case namedUser
    case liveactivities
}
