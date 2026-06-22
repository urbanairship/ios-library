/* Copyright Airship and Contributors */

public import AirshipCore

public import Foundation

/// AirshipMessageCenter module loader.
/// - Note: For internal use only. :nodoc:
@objc(UAMessageCenterSDKModule)
public class MessageCenterSDKModule: NSObject, AirshipSDKModule {

    public let actionsManifest: (any ActionsManifest)? = MessageCenterActionsManifest()
    public let components: [any AirshipComponent]

    init(messageCenter: DefaultMessageCenter) {
        self.components = [MessageCenterComponent(messageCenter: messageCenter)]
    }

    public static func load(_ args: AirshipModuleLoaderArgs) -> (any AirshipSDKModule)? {
        let messageCenter = DefaultMessageCenter(
            dataStore: args.dataStore,
            config: args.config,
            channel: args.channel,
            privacyManager: args.privacyManager,
            workManager: args.workManager,
            meteredUsage: args.meteredUsage,
            analytics: args.analytics
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


