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
@objc
public class AirshipChatModuleLoader : NSObject, UAModuleLoader, UAAirshipChatModuleLoaderFactory {

    private var module: UAComponent

    public init(_ module: AirshipChat) {
        self.module = module
    }

    public static func moduleLoader(with dataStore: UAPreferenceDataStore,
                                    config: UARuntimeConfig,
                                    channel: UAChannel) -> UAModuleLoader {
        let airshipChat = AirshipChat(dataStore: dataStore, config: config, channel: channel)
        return AirshipChatModuleLoader(airshipChat)
    }

    public func components() -> [UAComponent] {
        return [self.module]
    }
}
