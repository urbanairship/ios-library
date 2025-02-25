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
}
