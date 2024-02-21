/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

/// AirshipMessageCenter module loader.
/// @note For internal use only. :nodoc:
@objc(UAMessageCenterSDKModule)
public class MessageCenterSDKModule: NSObject, AirshipSDKModule {

    public let actionsManifest: ActionsManifest? = MessageCenterActionsManifest()
    public let components: [AirshipComponent]

    init(messageCenter: MessageCenter) {
        self.components = [MessageCenterComponent(messageCenter: messageCenter)]
    }

    public static func load(
        dependencies: [String: Any]
    ) -> AirshipSDKModule? {
        let dataStore = dependencies[SDKDependencyKeys.dataStore] as? PreferenceDataStore
        let config = dependencies[SDKDependencyKeys.config] as? RuntimeConfig
        let channel = dependencies[SDKDependencyKeys.channel] as? InternalAirshipChannelProtocol
        let privacyManager = dependencies[SDKDependencyKeys.privacyManager] as? AirshipPrivacyManager
        let workManager = dependencies[SDKDependencyKeys.workManager] as? AirshipWorkManagerProtocol

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
}


fileprivate struct MessageCenterActionsManifest : ActionsManifest {
    var manifest: [[String] : () -> ActionEntry] = [
        MessageCenterAction.defaultNames: {
            return ActionEntry(
                action: MessageCenterAction()
            )
        }
    ]
}


