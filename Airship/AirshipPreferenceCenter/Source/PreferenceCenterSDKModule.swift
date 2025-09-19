/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
public import AirshipCore
#endif

import Foundation

/// AirshipPreferenceCenter module loader.
/// @note For internal use only. :nodoc:
@objc(UAPreferenceCenterSDKModule)
public class PreferenceCenterSDKModule: NSObject, AirshipSDKModule {
    public let actionsManifest: (any ActionsManifest)? = nil
    public let components: [any AirshipComponent]

    public static func load(_ args: AirshiopModuleLoaderArgs) -> (any AirshipSDKModule)? {
        let preferenceCenter = PreferenceCenter(
            dataStore: args.dataStore,
            privacyManager: args.privacyManager,
            remoteData: args.remoteData,
            inputValidator: args.inputValidator
        )
        return PreferenceCenterSDKModule(preferenceCenter)
    }

    private init(_ preferenceCenter: PreferenceCenter) {
        self.components = [
            PreferenceCenterComponent(preferenceCenter: preferenceCenter)
        ]
    }
}
