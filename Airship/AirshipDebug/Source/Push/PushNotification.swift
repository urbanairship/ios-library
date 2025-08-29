/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

import Foundation

/// A wrapper for representing an Airship push in the Debug UI
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

    var payload: AirshipJSON {
        return (try? AirshipJSON.from(json: self.description)) ?? AirshipJSON.string(description)
    }

    init(userInfo: AirshipJSON) throws {
        self.description = try userInfo.toString()
        self.time = Date().timeIntervalSince1970
        self.alert = PushNotification.parseAlert(userInfo)
        self.pushID = userInfo.object?["_"]?.string ?? "MISSING_PUSH_ID"
    }

    init(pushData: PushData) {
        self.description = pushData.data ?? ""
        self.time = pushData.time
        self.alert = pushData.alert
        self.pushID = pushData.pushID ?? ""
    }

    private static func parseAlert(_ push: AirshipJSON) -> String? {
        guard let alert = push.object?["aps"]?.object?["alert"] else { return nil }

        if let string = alert.string {
            return string
        }

        return alert.object?["body"]?.string
    }
}
