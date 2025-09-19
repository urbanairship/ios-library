/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
public import AirshipCore
#endif

import Foundation

/// AirshipMessageCenter module loader.
/// @note For internal use only. :nodoc:
@objc(UAMessageCenterSDKModule)
public class MessageCenterSDKModule: NSObject, AirshipSDKModule {

    public let actionsManifest: (any ActionsManifest)? = MessageCenterActionsManifest()
    public let components: [any AirshipComponent]

    init(messageCenter: DefaultAirshipMessageCenter) {
        self.components = [MessageCenterComponent(messageCenter: messageCenter)]
    }

    public static func load(_ args: AirshiopModuleLoaderArgs) -> (any AirshipSDKModule)? {
        let messageCenter = DefaultAirshipMessageCenter(
            dataStore: args.dataStore,
            config: args.config,
            channel: args.channel,
            privacyManager: args.privacyManager,
            workManager: args.workManager
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


