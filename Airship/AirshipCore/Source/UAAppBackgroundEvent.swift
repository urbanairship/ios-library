/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc
public class UAAppBackgroundEvent : UAAppExitEvent {
    @objc
    public override var eventType : String {
        get {
            return "app_background"
        }
    }
}
