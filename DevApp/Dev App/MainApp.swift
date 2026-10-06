/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore
import AirshipScenes

#if DEBUG && canImport(AirshipDebug)
import AirshipDebug
#endif

@main
struct MainApp: App {
    
    let appRouter: AppRouter = AppRouter()
    let toast: Toast = Toast()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        UITestLaunch.prepare()
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
                .onChangeOfCompat(scenePhase) { phase in
                    if phase == .active {
                        print("App became active!")

                        // Clear the badge on active
                        Task {
                            try await Airship.push.resetBadge()
                        }
                    }
                }
#if DEBUG && canImport(AirshipDebug)
                .airshipDebug(triggers: [.shake, .cmdShiftD])
#endif
                .overlay {
                    // A scene screenshot should test the scene, not the home screen behind
                    // it: the home screen laid itself out a few pixels differently from
                    // launch to launch and every modal screenshot picked that up.
                    if UITestLaunch.hidesHomeScreen {
                        Color(white: 0.94).ignoresSafeArea()
                    }
                }
                .task {
                    await UITestLaunch.displayLayoutIfRequested(router: appRouter, toast: toast)
                }
        }
    }
}

/// UI-test hooks, driven by launch arguments (e.g. from a Maestro flow):
///
///     -uiTestMode true                     stable rendering: UIKit animations off, recents cleared
///
/// SwiftUI-driven transitions (e.g. the scene presentation fade) are not covered by
/// `UIView.setAnimationsEnabled`; flows wait them out with `waitForAnimationToEnd`.
///     -thomasLayout Scenes/Modal/foo.yml   display a bundled layout directly after launch
///     -thomasEmbeddedID "<embedded_id>"   with an Embedded layout: push a host view for that
///                                         embedded ID so the scene has somewhere to render
///
/// In test mode every remote image in the launched layout is swapped for a locally generated
/// placeholder, so screenshots exercise image sizing and cropping without touching the network.
@MainActor
enum UITestLaunch {

    /// Whether the app hides its home screen behind a flat color: test mode with a modal or
    /// banner layout launched directly. Embedded layouts need the pushed host view visible.
    static var hidesHomeScreen: Bool {
        UserDefaults.standard.bool(forKey: "uiTestMode")
            && UserDefaults.standard.string(forKey: "thomasLayout") != nil
            && UserDefaults.standard.string(forKey: "thomasEmbeddedID") == nil
    }

    static func prepare() {
        guard UserDefaults.standard.bool(forKey: "uiTestMode") else { return }
#if canImport(UIKit)
        UIView.setAnimationsEnabled(false)
#endif
        UserDefaults(suiteName: "airship.layout")?
            .removePersistentDomain(forName: "airship.layout")
    }

    static func displayLayoutIfRequested(router: AppRouter, toast: Toast) async {
        guard let path = UserDefaults.standard.string(forKey: "thomasLayout") else { return }
        guard Airship.isFlying else {
            toast.message = .init(text: "Cannot open \(path): Airship did not take off (check AirshipConfig.plist)", duration: 5.0)
            return
        }
        // Embedded scenes only render inside an `AirshipEmbeddedView` with a matching ID and
        // nothing on the home screen hosts the fixture IDs, so push a host first. The display
        // call below suspends for as long as the scene is showing, so it has to come last.
        if let embeddedID = UserDefaults.standard.string(forKey: "thomasEmbeddedID") {
            router.homePath = [.thomas(.embeddedHost(embeddedID: embeddedID))]
        }
        do {
            try await layoutFile(path: path).open(isUITest: UserDefaults.standard.bool(forKey: "uiTestMode"))
        } catch {
            toast.message = .init(text: "Failed to open \(path): \(error.localizedDescription)", duration: 5.0)
        }
    }

    private struct LaunchError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    private static func layoutFile(path: String) throws -> LayoutFile {
        let components = path.split(separator: "/").map(String.init)
        guard components.count == 3 else {
            throw LaunchError("Expected <Scenes|Messages>/<Category>/<file>: \(path)")
        }

        let type: LayoutType? = switch (components[0], components[1]) {
        case ("Scenes", "Modal"): .sceneModal
        case ("Scenes", "Banner"): .sceneBanner
        case ("Scenes", "Embedded"): .sceneEmbedded
        case ("Messages", "Modal"): .messageModal
        case ("Messages", "Banner"): .messageBanner
        case ("Messages", "Fullscreen"): .messageFullscreen
        case ("Messages", "HTML"): .messageHTML
        default: nil
        }
        guard let type else {
            throw LaunchError("Unknown layout directory: \(path)")
        }

        return LayoutFile(
            directory: "/\(components[0])/\(components[1])",
            fileName: components[2],
            type: type
        )
    }
}

/// Hosts a directly launched embedded scene for UI tests: a bounded, full-width frame with a
/// visible border, so auto and percent sizing resolve against a known box. The placeholder
/// stays visible when the scene never arrives, which makes a decode failure obvious in the
/// screenshot instead of leaving an empty screen.
struct UITestEmbeddedHostView: View {
    let embeddedID: String

    var body: some View {
        VStack {
            AirshipEmbeddedView(embeddedID: embeddedID) {
                Text("Placeholder")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.green)
            }
            .frame(maxWidth: .infinity, maxHeight: 320)
            .border(Color.red, width: 2)
            .padding()
            Spacer()
        }
        .navigationTitle(embeddedID)
        // This route only exists for UITestLaunch: the tab bar below it renders real,
        // async-loaded state (the message center unread badge), so it's a source of
        // screenshot diffs unrelated to the embedded scene under test.
#if !os(macOS)
        .toolbar(.hidden, for: .tabBar)
#endif
    }
}
