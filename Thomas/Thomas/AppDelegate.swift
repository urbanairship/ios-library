/* Copyright Airship and Contributors */

import AirshipCore
import Foundation
import SwiftUI
import AirshipAutomation

class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        do {
            var config = try AirshipConfig.default()
            config.isWebViewInspectionEnabled = true
            config.developmentLogLevel = .verbose
            config.productionLogLevel = .verbose
            try Airship.takeOff(config)
        } catch {
            showInvalidConfigAlert()
            return true
        }

        registerCustomViews()

        Airship.inAppAutomation.inAppMessaging.themeManager.htmlThemeExtender = { message, theme in
            theme.maxWidth = 300
            theme.maxHeight = 300
        }
        
        Task {
            // Set the icon badge to zero on startup (optional)
            try await Airship.push.resetBadge()
        }

        Airship.inAppAutomation.inAppMessaging.themeManager.htmlThemeExtender = { message, theme in
            if message.extras?.object?["squareview"]?.string == "true" {
                theme.maxWidth = (min(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)-24*2)
                theme.maxHeight = theme.maxWidth
            }
        }

        return true
    }

    func showInvalidConfigAlert() {
        let alertController = UIAlertController.init(
            title: "Invalid AirshipConfig.plist",
            message:
                "The AirshipConfig.plist must be a part of the app bundle and include a valid appkey and secret for the selected production level.",
            preferredStyle: .actionSheet
        )
        alertController.addAction(
            UIAlertAction.init(
                title: "Exit Application",
                style: UIAlertAction.Style.default,
                handler: { (UIAlertAction) in
                    exit(1)
                }
            )
        )

        DispatchQueue.main.async {
            alertController.popoverPresentationController?.sourceView =
                self.window?.rootViewController?.view

            self.window?.rootViewController?
                .present(alertController, animated: true, completion: nil)
        }
    }

    @MainActor
    private func registerCustomViews() {

        AirshipCustomViewManager.shared.register(name: "scene_controller_test") { args in
            SceneControllerTestView()
        }

        AirshipCustomViewManager.shared.register(name: "weather_custom_view") { args in
            WeatherView()
        }

        AirshipCustomViewManager.shared.register(name: "camera_custom_view") { args in
            CameraView()
        }

        #if !os(tvOS)
        AirshipCustomViewManager.shared.register(name: "map_custom_view") { args in
            MapRouteView()
        }

        AirshipCustomViewManager.shared.register(name: "biometric_login_custom_view") { args in
            BiometricLoginView()
        }
        #endif

        AirshipCustomViewManager.shared.fallbackBuilder = { args in
            ZStack {
                Text("Missing custom view \(args.name)")
                    .foregroundColor(Color.black)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .border(Color.red)
            .background(Color.white)
        }
    }
}


/// A view for manually testing the `SceneController` implementation.
///
/// This view observes a `SceneController` from the environment and provides
/// controls to test its navigation and dismiss functionality. It displays the
/// current state of `canGoBack` and `canGoForward`.
struct SceneControllerTestView: View {

    /// The scene controller for the current environment.
    @EnvironmentObject var sceneController: AirshipSceneController

    var body: some View {
        VStack(spacing: 20) {
            Text("Scene Controller Custom View")

            // MARK: - State Display
            VStack {
                Text("Navigation State")
                    .font(.headline)
                HStack {
                    Text("Can Go Back:")
                    Spacer()
                    Text(sceneController.pager.canGoBack ? "✅" : "❌")
                }
                HStack {
                    Text("Can Go Forward:")
                    Spacer()
                    Text(sceneController.pager.canGoNext ? "✅" : "❌")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)

            // MARK: - Navigation Controls
            HStack(spacing: 16) {
                Button(action: {
                    _ = sceneController.pager.navigate(request: .back)
                }) {
                    Label("Back", systemImage: "arrow.left")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!sceneController.pager.canGoBack)

                Button(action: {
                    _ = sceneController.pager.navigate(request: .next)
                }) {
                    Label("Next", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!sceneController.pager.canGoNext)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            // MARK: - Dismiss Controls
            VStack {
                Button("Dismiss", role: .destructive) {
                    sceneController.dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Dismiss and Cancel Future", role: .destructive) {
                    sceneController.dismiss(cancelFutureDisplays: true)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)

        }
        .padding()
    }
}

// MARK: - Preview
struct SceneControllerTestView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample controller for the preview
        let controller = AirshipSceneController()

        // You can change these values to test different states in the preview
        // controller.canGoBack = true
        // controller.canGoForward = true

        SceneControllerTestView()
            .environmentObject(controller)
    }
}

