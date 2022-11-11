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
            dependencies[SDKDependencyKeys.privacyManager] as! PrivacyManager
        let remoteDataProvider =
            dependencies[SDKDependencyKeys.remoteData] as! RemoteDataProvider

        let preferenceCenter = PreferenceCenter(
            dataStore: dataStore,
            privacyManager: privacyManager,
            remoteDataProvider: remoteDataProvider
        )
        return PreferenceCenterSDKModule(preferenceCenter)
    }
}
