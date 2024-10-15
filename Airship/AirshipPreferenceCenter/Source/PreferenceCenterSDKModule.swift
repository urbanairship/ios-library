/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// AirshipPreferenceCenter module loader.
/// @note For internal use only. :nodoc:
@objc(UAPreferenceCenterSDKModule)
public class PreferenceCenterSDKModule: NSObject, AirshipSDKModule {
    public let actionsManifest: ActionsManifest? = nil
    public let components: [AirshipComponent]

    public static func load(dependencies: [String : Any]) -> AirshipSDKModule? {
        let dataStore =
            dependencies[SDKDependencyKeys.dataStore] as! PreferenceDataStore
        let privacyManager =
            dependencies[SDKDependencyKeys.privacyManager] as! AirshipPrivacyManager
        let remoteData =
            dependencies[SDKDependencyKeys.remoteData] as! RemoteDataProtocol

        let preferenceCenter = PreferenceCenter(
            dataStore: dataStore,
            privacyManager: privacyManager,
            remoteData: remoteData
        )
        return PreferenceCenterSDKModule(preferenceCenter)
    }


    private init(_ preferenceCenter: PreferenceCenter) {
        self.components = [
            PreferenceCenterComponent(preferenceCenter: preferenceCenter)
        ]
    }
}
