/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

/**
 * AirshipChat module loader.
 * @note For internal use only. :nodoc:
 */
@available(iOS 13.0, *)
@objc(UAirshipChatModuleLoader)
public class AirshipChatModuleLoader : NSObject, UAModuleLoader, UAAirshipChatModuleLoaderFactory {

    private var module: UAComponent

    public init(_ module: Chat) {
        self.module = module
    }

    public static func moduleLoader(with dataStore: UAPreferenceDataStore,
                                    config: UARuntimeConfig,
                                    channel: UAChannel,
                                    privacyManager: UAPrivacyManager) -> UAModuleLoader {
        let airshipChat = Chat(dataStore: dataStore, config: config, channel: channel, privacyManager: privacyManager)
        return AirshipChatModuleLoader(airshipChat)
    }

    public func components() -> [UAComponent] {
        return [self.module]
    }

    public func registerActions(_ registry: UAActionRegistry) {
        registry.register(OpenChatAction(), name: OpenChatAction.name)
    }
}
