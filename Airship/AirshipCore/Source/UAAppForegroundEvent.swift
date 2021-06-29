/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc
public class UAAppForegroundEvent : UAAppInitEvent {
    public override func gatherData() -> [AnyHashable : Any] {
        var data = super.gatherData()
        data.removeValue(forKey: "foreground")
        return data
    }

    public override var eventType: String {
        get {
            return "app_foreground"
        }
    }
}
