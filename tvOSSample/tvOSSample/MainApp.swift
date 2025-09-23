/* Copyright Airship and Contributors */

import SwiftUI

@main
struct MainApp: App {
    static let preferenceCenterID = "app_default"

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(AppState.shared)
        }
    }
}
