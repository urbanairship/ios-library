/* Copyright Airship and Contributors */

import AirshipCore
import Foundation

/// A wrapper for representing an Airship push notification in the Debug UI.
///
/// `PushNotification` encapsulates push notification data for display in the debug interface.
/// It provides a simplified representation of push notifications with the essential
/// information needed for debugging and monitoring.
///
/// ## Usage
///
/// ```swift
/// // Access push notifications through the debug manager
/// let pushes = await Airship.internalDebugManager.pushNotifications()
/// for push in pushes {
///     print("Push: \(push.alert ?? "No alert") at \(Date(timeIntervalSince1970: push.time))")
/// }
/// ```
///
/// - Note: This struct is thread-safe and can be used across different threads.
struct PushNotification: Equatable, Hashable, CustomStringConvertible, Sendable {

    /// The unique push ID.
    var pushID: String

    /// The push alert message.
    var alert: String?

    /// The time the push was created (as a TimeInterval since 1970).
    var time: TimeInterval

    /// The push data description as a JSON string.
    public var description: String

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
