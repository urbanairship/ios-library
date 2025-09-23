/* Copyright Airship and Contributors */

import Combine
import SwiftUI

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
    }
}


