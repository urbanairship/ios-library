/* Copyright Airship and Contributors */

/// - Note: For Internal use only :nodoc:
class DeviceRegistrationEvent: NSObject, Event {

    init(
        channelID: String?,
        deviceToken: String
    ) {
        var data: [AnyHashable: Any] = [:]
        data["device_token"] = deviceToken
        data["channel_id"] = channelID
        self._data = data
    }

    @objc
    public var priority: EventPriority {
        return .normal
    }

    @objc
    public var eventType: String {
        return "device_registration"
    }

    private let _data: [AnyHashable: Any]

    @objc
    public var data: [AnyHashable: Any] {
        return self._data
    }
}
