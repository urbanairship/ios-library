/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc(UAAppBackgroundEvent)
public class AppBackgroundEvent : AppExitEvent {
    @objc
    public override var eventType : String {
        get {
            return "app_background"
        }
    }
}
