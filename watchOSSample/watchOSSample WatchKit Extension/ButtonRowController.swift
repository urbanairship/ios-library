/* Copyright Airship and Contributors */

import AirshipCore
import Foundation
import WatchKit

class ButtonRowController: NSObject {
    @IBOutlet weak var itemButton: WKInterfaceButton!

    @IBAction func buttonAction() {
        Airship.push.userPushNotificationsEnabled = true
    }
}
