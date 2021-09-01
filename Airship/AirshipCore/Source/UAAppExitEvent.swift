/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc
public class UAAppExitEvent : NSObject, UAEvent {
    private let _data : [AnyHashable : Any]

    @objc
    public var analyticsSupplier: () -> AnalyticsProtocol? = {
        return UAirship.analytics()
    }

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
        var data: [AnyHashable : Any] = [:]
        data["push_id"] = self.analyticsSupplier()?.conversionSendID
        data["metadata"] = self.analyticsSupplier()?.conversionPushMetadata
        data["connection_type"] = UAUtils.connectionType()
        self._data = data

        super.init()
    }
}
