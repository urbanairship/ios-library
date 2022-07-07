/* Copyright Airship and Contributors */

import Foundation
import WatchKit
import AirshipCore

class ButtonRowController: NSObject {
    @IBOutlet weak var itemButton: WKInterfaceButton!
    
    @IBAction func buttonAction() {
        Airship.push.userPushNotificationsEnabled = true
    }
}
