/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc
public class UADeviceRegistrationEvent : NSObject, UAEvent {
    @objc
    public var priority: UAEventPriority {
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

    @objc
    public override init() {
        var data: [AnyHashable : Any] = [:]
        if UAirship.shared()?.privacyManager.isEnabled(.push) ?? false {
            data["device_token"] = UAirship.push()?.deviceToken
        }

        data["channel_id"] = UAirship.channel()?.identifier

        self._data = data

        super.init()
    }
}
