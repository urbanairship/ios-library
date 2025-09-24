/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore

@main
struct ThomasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}
