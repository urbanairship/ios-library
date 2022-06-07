/* Copyright Airship and Contributors */

/**
 * - Note: For Internal use only :nodoc:
 */
class DeviceRegistrationEvent : NSObject, Event {
    
    init(channel: ChannelProtocol?,
                push: InternalPushProtocol?,
                privacyManager: PrivacyManager?) {
         
        var data: [AnyHashable : Any] = [:]
        if privacyManager?.isEnabled(.push) == true {
            data["device_token"] = push?.deviceToken
        }

        data["channel_id"] = channel?.identifier

        self._data = data
    }
    
    @objc
    public override convenience init() {
        self.init(channel: Airship.channel, push: Airship.push, privacyManager: Airship.shared.privacyManager)
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
            return "device_registration"
        }
    }

    private let _data : [AnyHashable : Any]

    @objc
    public var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }
}
