/* Copyright Airship and Contributors */

/**
 * - Note: For Internal use only :nodoc:
 */
class AppForegroundEvent : AppInitEvent {
    open override func gatherData() -> [AnyHashable : Any] {
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
