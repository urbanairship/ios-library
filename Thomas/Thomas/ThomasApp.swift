/* Copyright Airship and Contributors */

import SwiftUI

@main
struct ThomasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            LayoutsList()
        }
    }
}
