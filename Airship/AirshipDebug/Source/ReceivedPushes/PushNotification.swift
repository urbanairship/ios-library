/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

/**
 * A wrapper for representing an Airship push in the Debug UI
 */
struct PushNotification: Equatable, Hashable, CustomStringConvertible {

    /**
     * The unique push ID.
     */
    var pushID: String

    /**
     * The push alert.
     */
    var alert: String?

    /**
     * The time the push was created.
     */
    var time: TimeInterval

    /**
     * The push data description.
     */
    var description: String

    init(push: [AnyHashable: Any]) throws {
        self.description = String(
            data: try JSONSerialization.data(
            withJSONObject: push,
            options: .prettyPrinted
            ),
            encoding:.utf8
        ) ?? ""
        self.time = Date().timeIntervalSince1970
        self.alert = PushNotification.parseAlert(userInfo: push)
        self.pushID = push[AnyHashable("_")] as? String ?? "MISSING_PUSH_ID"
    }
    
    init(pushData: PushData) {
        self.description = pushData.data ?? ""
        self.time = pushData.time
        self.alert = pushData.alert
        self.pushID = pushData.pushID ?? ""
    }

    private static func parseAlert(userInfo: [AnyHashable: Any]) -> String? {
        guard let aps = userInfo["aps"] as? [String: Any] else { return nil }

        if let alert = aps["alert"] as? String {
            return alert
        }

        if let alert = aps["alert"] as? [String: Any],
           let body = alert["body"] as? String
        {
           return body
        }

        return nil
    }
}
