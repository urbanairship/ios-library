import UIKit
import AirshipKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        do {
            try Airship.takeOff(launchOptions: launchOptions)
            
            print("Airship takeOff successful")
            
            Task {
                if let channelID = await Airship.channel.identifier {
                    print("Channel ID: \(channelID)")
                }

                Airship.channel.editTags()
                    .add("david")

                // Enable user notifications
                Airship.push.userPushNotificationsEnabled = true
            }
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
