/* Copyright Airship and Contributors */

/// Fetches device info.
///
/// Expected argument values: none.
///
/// Valid situations: `ActionSituation.launchedFromPush`,
/// `ActionSituation.webViewInvocation`, `ActionSituation.manualInvocation`,
/// `ActionSituation.foregroundInteractiveButton`, `ActionSituation.backgroundInteractiveButton`,
/// and `ActionSituation.automation`
///
/// Result value: JSON payload containing the device's channel ID, named user ID, push opt-in status,
/// location enabled status, and tags. An example response as JSON:
/// {
///     "channel_id": "9c36e8c7-5a73-47c0-9716-99fd3d4197d5",
///     "push_opt_in": true,
///     "location_enabled": true,
///     "named_user": "cool_user",
///     "tags": ["tag1", "tag2, "tag3"]
/// }
///
public final class FetchDeviceInfoAction: AirshipAction {

    /// Default names - "fetch_device_info", "^+fdi"
    public static let defaultNames = ["fetch_device_info", "^+fdi"]

    /// Default predicate - only accepts `ActionSituation.manualInvocation` and `ActionSituation.webViewInvocation`
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.situation == .manualInvocation
            || args.situation == .webViewInvocation
    }

    // Channel ID key
    public static let channelID = "channel_id"

    // Named user key
    public static let namedUser = "named_user"

    // Tags key
    public static let tags = "tags"

    // Push opt-in key
    public static let pushOptIn = "push_opt_in"

    private let channel: @Sendable () -> AirshipChannelProtocol
    private let contact: @Sendable () -> AirshipContactProtocol
    private let push: @Sendable () -> AirshipPushProtocol

    public convenience init() {
        self.init(
            channel: Airship.componentSupplier(),
            contact: Airship.componentSupplier(),
            push: Airship.componentSupplier()
        )
    }

    init(
        channel: @escaping @Sendable () -> AirshipChannelProtocol,
        contact: @escaping @Sendable () -> AirshipContactProtocol,
        push: @escaping @Sendable () -> AirshipPushProtocol
    ) {
        self.channel = channel
        self.contact = contact
        self.push = push
    }


    public func accepts(arguments: ActionArguments) async -> Bool {
        return true
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let info = DeviceInfo(
            channelID: channel().identifier,
            pushOptIn: await push().isPushNotificationsOptedIn,
            namedUser: await contact().namedUserID,
            tags: channel().tags
        )

        return try AirshipJSON.wrap(info)
    }
}


fileprivate struct DeviceInfo: Encodable {
    let channelID: String?
    let pushOptIn: Bool
    let namedUser: String?
    let tags: [String]

    init(channelID: String?, pushOptIn: Bool, namedUser: String?, tags: [String]) {
        self.channelID = channelID
        self.pushOptIn = pushOptIn
        self.namedUser = namedUser
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case channelID = "channel_id"
        case pushOptIn = "push_opt_in"
        case namedUser = "named_user"
        case tags = "tags"
    }
}
