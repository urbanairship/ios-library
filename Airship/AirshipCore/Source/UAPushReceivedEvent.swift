/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc
public class UAPushReceivedEvent : UAEvent {

    @objc
    public override var eventType : String {
        get {
            return "push_received"
        }
    }

    private let _data : [AnyHashable : Any]

    @objc
    public override var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }

    @objc
    public init(notification: [AnyHashable : Any]) {
        var data: [AnyHashable : Any] = [:]
        data["metadata"] = notification["com.urbanairship.metadata"]
        data["push_id"] = notification["_"] ?? "MISSING_SEND_ID"

        self._data = data

        super.init()
    }
}
