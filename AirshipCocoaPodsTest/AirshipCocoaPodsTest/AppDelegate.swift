import UIKit
import AirshipKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        var config = AirshipConfig()
        config.defaultAppKey = "YOUR APP KEY"
        config.defaultAppSecret = "YOUR APP SECRET"
        
        // Configure Airship
        do {
            try Airship.takeOff(config, launchOptions: launchOptions)
        } catch {
            print("ERROR: Airship takeOff failed: \(error)")
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
