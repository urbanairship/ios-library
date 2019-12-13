/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

/**
 * A wrapper for representing an Airship push in the Debug UI
 */
struct PushNotification {
    let prettyTypes:[String:String] = [
        "push_resolution" : "Push Resolution",
        "app_background" : "Backgound",
        "push_display" : "Push Display"
    ]

    /**
     * The unique push ID.
     */
    var pushID:String

    /**
     * The push alert.
     */
    var alert:String

    /**
     * The time the push was created.
     */
    var time:Double

    /**
     * The push data description.
     */
    var data:String

    init(push:UANotificationContent) {
        self.data = String(data: try! JSONSerialization.data(withJSONObject:push.notificationInfo, options:.prettyPrinted), encoding:.utf8) ?? ""
        print(push)
        print(push.notificationInfo)
//        print(push.self)
//        self.data = push.alertBody!
        self.time = Date().timeIntervalSince1970
        let aps = push.notificationInfo[AnyHashable("aps")] as? [String:Any]
        self.alert = aps?["alert"] as? String ?? "No Alert"
        self.pushID = push.notificationInfo[AnyHashable("_")] as! String
    }
    
    init(pushData: PushData) {
        self.data = pushData.data ?? ""
        self.time = pushData.time
        self.alert = pushData.alert ?? "No Alert"
        self.pushID = pushData.pushID ?? ""
    }
}
