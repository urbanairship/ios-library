/* Copyright Airship and Contributors */

/**
 * Fetches device info.
 *
 * This action is registered under the names fetch_device_info and ^fdi.
 *
 * Expected argument values: none.
 *
 * Valid situations: UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, UASituationBackgroundInteractiveButton,
 * and UASituationAutomation
 *
 * Result value: JSON payload containing the device's channel ID, named user ID, push opt-in status,
 * location enabled status, and tags. An example response as JSON:
 * {
 *     "channel_id": "9c36e8c7-5a73-47c0-9716-99fd3d4197d5",
 *     "push_opt_in": true,
 *     "location_enabled": true,
 *     "named_user": "cool_user",
 *     "tags": ["tag1", "tag2, "tag3"]
 * }
 *
 *
 * Default Registration Predicate: Only accepts UASituationManualInvocation and UASituationWebViewInvocation
 */
@objc(UAFetchDeviceInfoAction)
public class FetchDeviceInfoAction : NSObject, UAAction {
    
    @objc
    public static let name = "fetch_device_info"
    
    @objc
    public static let shortName = "^fdi"
    
    // Channel ID key
    @objc
    public static let channelID = "channel_id"
    
    // Named user key
    @objc
    public static let namedUser = "named_user"
    
    // Tags key
    @objc
    public static let tags = "tags"
    
    // Push opt-in key
    @objc
    public static let pushOptIn = "push_opt_in"
    
    // Location enabled key
    @objc
    public static let locationEnabled  = "location_enabled"

    public func acceptsArguments(_ arguments: UAActionArguments) -> Bool {
        return true
    }
    
    public func perform(with arguments: UAActionArguments, completionHandler: UAActionCompletionHandler) {
        var dict: [String : Any] = [:]
        dict[FetchDeviceInfoAction.channelID] = UAirship.channel().identifier
        dict[FetchDeviceInfoAction.namedUser] = UAirship.contact().namedUserID
        
        let tags = UAirship.channel().tags
        if (!tags.isEmpty) {
            dict[FetchDeviceInfoAction.tags] = tags
        }
        
        dict[FetchDeviceInfoAction.pushOptIn] = UAirship.push().authorizedNotificationSettings != []
        dict[FetchDeviceInfoAction.locationEnabled] = UAirship.shared().locationProvider?.isLocationUpdatesEnabled
        completionHandler(UAActionResult(value: dict))
    }
}
