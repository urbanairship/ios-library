/* Copyright 2017 Urban Airship and Contributors */

import UIKit
import AirshipKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UARegistrationDelegate {

    var window: UIWindow?
    var inboxDelegate: InboxDelegate?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {


        let config = UAConfig.default()

        UAirship.setLogLevel(UALogLevel.trace)

        config.messageCenterStyleConfig = "UAMessageCenterDefaultStyle"

        // Call takeOff (which creates the UAirship singleton)
        UAirship.takeOff(config)

        // Set the icon badge to zero on startup (optional)
        UAirship.push()?.resetBadge()

        return true
    }
}

