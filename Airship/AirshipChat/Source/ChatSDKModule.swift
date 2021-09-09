/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * AirshipChat SDK module.
 * - NOTE: For internal use only. :nodoc:
 */
@objc(UAChatSDKModule)
public class ChatSDKModule : NSObject, SDKModule {
    private let chatComponents: [Component]

    @available(iOS 13, *)
    private init(_ chat: Chat) {
        self.chatComponents = [chat]
    }
    
    public static func load(withDependencies dependencies: [AnyHashable : Any]) -> SDKModule? {
        guard #available(iOS 13, *) else {
            return nil
        }
        
        let dataStore = dependencies[SDKDependencyKeys.dataStore] as! PreferenceDataStore
        let config = dependencies[SDKDependencyKeys.config] as! RuntimeConfig
        let channel = dependencies[SDKDependencyKeys.channel] as! Channel
        let privacyManager = dependencies[SDKDependencyKeys.privacyManager] as! PrivacyManager
        
        let airshipChat = Chat(dataStore: dataStore,
                               config: config,
                               channel: channel,
                               privacyManager: privacyManager)
        return ChatSDKModule(airshipChat)
    }
    
    public func components() -> [Component] {
        return self.chatComponents
    }
    
    public func actionsPlist() -> String? {
        guard #available(iOS 13, *) else {
            return nil
        }
        return ChatResources.bundle()?.path(forResource: "UAChatActions", ofType: "plist")
    }
}
