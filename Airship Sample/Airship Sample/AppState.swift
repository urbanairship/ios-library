import SwiftUI
import AirshipCore
import AirshipMessageCenter
import Combine

class AppState: ObservableObject {
    static let shared = AppState()

    @Published
    var selectedTab: SampleTabs = .home

    @Published
    var homeDestination: HomeDestination? = nil

    @Published
    var messageID: String? = nil

    @Published
    var messageCount = 0;

    @Published
    var toastMessage: Toast.Message?

    private var subscriptions = Set<AnyCancellable>()

    init() {
        if (Airship.isFlying) {
            self.messageCount = MessageCenter.shared.messageList.unreadCount
            NotificationCenter.default
                .publisher(for: NSNotification.Name.UAInboxMessageListUpdated)
                .sink { _ in
                    self.messageCount = MessageCenter.shared.messageList.unreadCount
                }
                .store(in: &self.subscriptions)
        }
    }

}

enum SampleTabs: Hashable {
    case home
    case messageCenter
    case preferenceCenter
}

enum HomeDestination: Hashable {
    case settings
    case namedUser
    case liveactivities
}


