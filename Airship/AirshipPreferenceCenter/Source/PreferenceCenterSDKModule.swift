/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

/// AirshipPreferenceCenter module loader.
/// @note For internal use only. :nodoc:

@objc(UAPreferenceCenterSDKModule)
public class PreferenceCenterSDKModule: NSObject, SDKModule {

    private let preferenceCenter: PreferenceCenter

    public init(_ preferenceCenter: PreferenceCenter) {
        self.preferenceCenter = preferenceCenter
    }

    public func components() -> [Component] {
        return [self.preferenceCenter]
    }

    public static func load(withDependencies dependencies: [AnyHashable: Any])
        -> SDKModule?
    {
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
}
