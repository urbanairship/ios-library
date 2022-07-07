/* Copyright Airship and Contributors */

/**
 * - Note: For Internal use only :nodoc:
 */
class AppExitEvent: NSObject, Event {
    private lazy var analytics = Airship.requireComponent(ofType: AnalyticsProtocol.self)
    
    convenience init(analytics: AnalyticsProtocol) {
        self.init()
        self.analytics = analytics
    }
    
    @objc
    public var priority: EventPriority {
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
            return self.gatherData()
        }
    }
    
    open func gatherData() -> [AnyHashable : Any] {
        var data: [AnyHashable : Any] = [:]

        data["push_id"] = self.analytics.conversionSendID
        data["metadata"] = self.analytics.conversionPushMetadata
        #if !os(watchOS)
        data["connection_type"] = Utils.connectionType()
        #endif

        return data
    }
    
}
