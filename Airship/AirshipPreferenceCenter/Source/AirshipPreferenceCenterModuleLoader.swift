/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * AirshipPreferenceCenter module loader.
 * @note For internal use only. :nodoc:
 */

@objc(UAirshipPreferenceCenterModuleLoader)
public class AirshipPreferenceCenterModuleLoader : NSObject, UAModuleLoader, UAPreferenceCenterModuleLoaderFactory {
    
    private var module : UAComponent
    
    public init(_ module : PreferenceCenter) {
        self.module = module
    }
    
    public static func moduleLoader(with dataStore: UAPreferenceDataStore,
                                    privacyManager: UAPrivacyManager,
                                    remoteDataProvider: RemoteDataProvider) -> UAModuleLoader {
        let preferenceCenter = PreferenceCenter(dataStore: dataStore, privacyManager: privacyManager, remoteDataProvider: remoteDataProvider)
        return AirshipPreferenceCenterModuleLoader(preferenceCenter)
    }
    
    public func components() -> [UAComponent] {
        return [self.module]
    }
}


