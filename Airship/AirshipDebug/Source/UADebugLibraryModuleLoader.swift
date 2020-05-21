/* Copyright Airship and Contributors */
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

@objc public class UADebugLibraryModuleLoader : NSObject, UAModuleLoader, UADebugLibraryModuleLoaderFactory {
    public static func debugLibraryModuleLoader(with analytics: UAAnalytics) -> UAModuleLoader {
        AirshipDebug.takeOff(analytics)

        return UADebugLibraryModuleLoader()
    }
}
