/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
    import AirshipCore
#endif

/// AirshipMessageCenter module loader.
/// @note For internal use only. :nodoc:
@objc(UAMessageCenterSDKModule)
public class MessageCenterSDKModule: NSObject, SDKModule {

    private let messageCenter: MessageCenter

    init(messageCenter: MessageCenter) {
        self.messageCenter = messageCenter
    }

    public init(_ messageCenter: MessageCenter) {
        self.messageCenter = messageCenter
    }

    public func components() -> [Component] {
        return [self.messageCenter]
    }

    public static func load(withDependencies dependencies: [AnyHashable: Any])
        -> SDKModule?
    {
        let dataStore =
            dependencies[SDKDependencyKeys.dataStore] as? PreferenceDataStore
        let config = dependencies[SDKDependencyKeys.config] as? RuntimeConfig
        let channel = dependencies[SDKDependencyKeys.channel] as? Channel
        let privacyManager =
            dependencies[SDKDependencyKeys.privacyManager] as? PrivacyManager
        let workManager =
            dependencies[SDKDependencyKeys.workManager]
            as? AirshipWorkManagerProtocol

        guard let dataStore = dataStore,
            let config = config,
            let channel = channel,
            let privacyManager = privacyManager,
            let workManager = workManager
        else {
            return nil
        }

        let messageCenter = MessageCenter(
            dataStore: dataStore,
            config: config,
            channel: channel,
            privacyManager: privacyManager,
            workManager: workManager
        )

        return MessageCenterSDKModule(messageCenter: messageCenter)
    }

    public func actionsPlist() -> String? {
        return MessageCenterResources.bundle?
            .path(
                forResource: "UAMessageCenterActions",
                ofType: "plist"
            )
    }
}
