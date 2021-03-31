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
@objc
public class AirshipChatModuleLoader : NSObject, UAModuleLoader, UAAirshipChatModuleLoaderFactory {

    private var module: AirshipChat

    public init(_ module: AirshipChat) {
        self.module = module
    }

    public static func moduleLoader(with dataStore: UAPreferenceDataStore,
                                    channel: UAChannel,
                                    push: UAPush) -> UAModuleLoader {
        let airshipChat = AirshipChat(dataStore: dataStore, channel: channel, push: push)
        return AirshipChatModuleLoader(airshipChat)
    }

    public func components() -> [UAComponent] {
        return [self.module]
    }
}
