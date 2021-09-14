/* Copyright Airship and Contributors */

/**
 * - Note: For Internal use only :nodoc:
 */
@objc(UAInteractiveNotificationEvent)
@available(tvOS, unavailable)
public class InteractiveNotificationEvent : NSObject, Event {
    private static let notificationEventCharacterLimit = 255

    @objc
    public var eventType : String {
        get {
            return "interactive_notification_action"
        }
    }

    private let _data : [AnyHashable : Any]

    @objc
    public var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }

    @objc
    public var priority : EventPriority {
        get {
            return .high
        }
    }

    @objc
    public init(action: UNNotificationAction,
                category: String,
                notification: [AnyHashable : Any],
                responseText: String?) {

        #if os(tvOS)
        let foreground = false
        #else
        let foreground = (action.options.rawValue & UNNotificationActionOptions.foreground.rawValue) > 0
        #endif

        var data: [AnyHashable : Any] = [:]
        data["button_group"] = category
        data["button_id"] = action.identifier
        data["button_description"] = action.title
        data["foreground"] = foreground.toBoolString()
        data["send_id"] = notification["_"]

        if let responseText = responseText {
            if responseText.count > 255 {
                AirshipLogger.warn(
                    "Interactive Notification \(responseText) value exceeds \(255) characters. Truncating to max chars")
                data["user_input"] = responseText.prefix(255)
            } else {
                data["user_input"] = responseText
            }
        }

        self._data = data
        super.init()
    }
}

private extension Bool {
    func toBoolString() -> String {
        return self ? "true" : "false"
    }
}
