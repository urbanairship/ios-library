/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore

#if DEBUG && canImport(AirshipDebug)
import AirshipDebug
#endif

@main
struct MainApp: App {
    
    let appRouter: AppRouter = AppRouter()
    let toast: Toast = Toast()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            // Initialize Airship
            try AirshipInitializer.initialize()

            // Setup optional features
            LiveActivityHandler.setup()
            PushNotificationHandler.setup()
            DeepLinkHandler.setup(router: appRouter) { [weak toast] error in
                toast?.message = .init(text: "Invalid deepLink \(error)", duration: 2.0)
            }
        } catch {
            toast.message = .init(text: "Failed to initialize airship \(error)", duration: 2.0)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(appRouter)
                .environmentObject(toast)
                .airshipOnChangeOf(scenePhase) { phase in
                    if phase == .active {
                        print("App became active!")

                        // Clear the badge on active
                        Task {
                            try await Airship.push.resetBadge()
                        }
                    }
                }
#if DEBUG && canImport(AirshipDebug)
                .airshipDebugOnShake()
#endif
        }
    }
}
