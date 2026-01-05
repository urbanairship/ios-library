/* Copyright Airship and Contributors */

import Combine
import SwiftUI
import AirshipMessageCenter

@MainActor
final class AppRouter: ObservableObject {
    let preferenceCenterID: String = "app_default"

    @Published
    var selectedTab: Tabs = .home

    @Published
    var homePath: [HomeRoute] = []

    enum Tabs: Sendable, Equatable, Hashable {
        case home
        case messageCenter
        case preferenceCenter
    }

    enum HomeRoute: Hashable {
        case namedUser
        case thomas(ThomasRoute)
    }
    
    enum ThomasRoute: Hashable {
        case home
        case layoutList(LayoutType)
    }

    let messageCenterController: MessageCenterController = MessageCenterController()

    public func navigateMessagCenter(messageID: String? = nil) {
        messageCenterController.navigate(messageID: messageID)
        selectedTab = .messageCenter
    }
}

extension AppRouter.HomeRoute {
    @MainActor
    @ViewBuilder
    func destination() -> some View {
        switch self {
        case .namedUser: NamedUserView()
        case .thomas(let route): route.destination()
        }
    }
}

extension AppRouter.ThomasRoute {
    
    @MainActor
    @ViewBuilder
    func destination() -> some View {
        switch self {
        case .home: ThomasLayoutListView()
        case .layoutList(let type):
            if case .sceneEmbedded = type {
                EmbeddedPlaygroundMenuView()
                    .navigationTitle("Embedded")
            } else {
                LayoutsList(layoutType: type, onOpen: ThomasLayoutViewModel.saveToRecent)
                    .navigationTitle(type.navigationTitle)
            }
        }
    }
}

private extension LayoutType {
    var navigationTitle: String {
        switch(self) {
        case .sceneModal: return "Modals"
        case .sceneBanner: return "Banners"
        case .sceneEmbedded: return "Embedded"
        case .messageModal: return "Modals"
        case .messageBanner: return "Banners"
        case .messageFullscreen: return "Fullscreen"
        case .messageHTML: return "HTML"
        }
    }
}


