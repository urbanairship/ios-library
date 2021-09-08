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
public class FetchDeviceInfoAction : NSObject, Action {
    
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

    private let channel: () -> ChannelProtocol
    private let contact: () -> ContactProtocol
    private let push: () -> PushProtocol
    private let location: () -> UALocationProvider?
    
    @objc
    public override convenience init() {
        self.init(channel: Channel.supplier,
                  contact: Contact.supplier,
                  push: { return Airship.push },
                  location: { return Airship.shared.locationProvider })
    }
    
    @objc
    public init(channel: @escaping () -> ChannelProtocol,
                contact: @escaping () -> ContactProtocol,
                push: @escaping () -> PushProtocol,
                location: @escaping () -> UALocationProvider?) {
        self.channel = channel
        self.contact = contact
        self.push = push
        self.location = location
    }
    
    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        return true
    }
    
    public func perform(with arguments: ActionArguments, completionHandler: UAActionCompletionHandler) {
        var dict: [String : Any] = [:]
        let channel = self.channel()
        let contact = self.contact()
        let push = self.push()
        let location = self.location()

        dict[FetchDeviceInfoAction.channelID] = channel.identifier
        dict[FetchDeviceInfoAction.namedUser] = contact.namedUserID
        
        let tags = channel.tags
        if (!tags.isEmpty) {
            dict[FetchDeviceInfoAction.tags] = tags
        }
        
        dict[FetchDeviceInfoAction.pushOptIn] = push.authorizedNotificationSettings != []
        dict[FetchDeviceInfoAction.locationEnabled] = location?.isLocationUpdatesEnabled
        completionHandler(ActionResult(value: dict))
    }
}
