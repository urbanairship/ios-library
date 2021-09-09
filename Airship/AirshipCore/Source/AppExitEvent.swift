/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc(UAAppExitEvent)
public class AppExitEvent : NSObject, Event {
    private let _data : [AnyHashable : Any]

    @objc
    public var priority: UAEventPriority {
        get {
            return .normal
        }
    }

    @objc
    public var eventType : String {
        get {
            return "app_exit"
        }
    }

    @objc
    public var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }

    @objc
    public override init() {
        let analytics = Airship.requireComponent(ofType: AnalyticsProtocol.self)
        var data: [AnyHashable : Any] = [:]
        data["push_id"] = analytics.conversionSendID
        data["metadata"] = analytics.conversionPushMetadata
        data["connection_type"] = Utils.connectionType()
        self._data = data

        super.init()
    }
}
