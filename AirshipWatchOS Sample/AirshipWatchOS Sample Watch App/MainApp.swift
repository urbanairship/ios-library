/* Copyright Urban Airship and Contributors */

import SwiftUI

@main
struct MainApp: App {

    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
