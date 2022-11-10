/* Copyright Urban Airship and Contributors */

import SwiftUI
import AirshipMessageCenter

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

