/* Copyright Urban Airship and Contributors */

import SwiftUI

@main
struct MainApp: App {
    static let preferenceCenterID = "accessibility_sample_preferences"

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(AppState.shared)
        }
    }
}
