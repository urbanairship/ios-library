/* Copyright Airship and Contributors */

class PushReceivedEvent: NSObject, Event {

    @objc
    public var priority: EventPriority {
        return .normal
    }

    @objc
    public var eventType: String {
        return "push_received"
    }

    private let _data: [AnyHashable: Any]

    @objc
    public var data: [AnyHashable: Any] {
        return self._data
    }

    @objc
    public init(notification: [AnyHashable: Any]) {
        var data: [AnyHashable: Any] = [:]
        data["metadata"] = notification["com.urbanairship.metadata"]
        data["push_id"] = notification["_"] ?? "MISSING_SEND_ID"

        self._data = data

        super.init()
    }
}
