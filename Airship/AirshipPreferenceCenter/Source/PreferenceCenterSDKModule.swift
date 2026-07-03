/* Copyright Airship and Contributors */

public import AirshipCore

public import Foundation

/// AirshipPreferenceCenter module loader.
/// - Note: For internal use only. :nodoc:
@objc(UAPreferenceCenterSDKModule)
@_spi(AirshipInternal)
public class PreferenceCenterSDKModule: NSObject, AirshipSDKModule {
    public let actionsManifest: (any ActionsManifest)? = nil
    public let components: [any AirshipComponent]

    public static func load(_ args: AirshipModuleLoaderArgs) -> (any AirshipSDKModule)? {
        let preferenceCenter = DefaultPreferenceCenter(
            dataStore: args.dataStore,
            privacyManager: args.privacyManager,
            remoteData: args.remoteData,
            inputValidator: args.inputValidator
        )
        return PreferenceCenterSDKModule(preferenceCenter)
    }

    private init(_ preferenceCenter: DefaultPreferenceCenter) {
        self.components = [
            PreferenceCenterComponent(preferenceCenter: preferenceCenter)
        ]
    }
}
