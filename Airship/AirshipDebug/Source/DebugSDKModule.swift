/* Copyright Airship and Contributors */
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

@objc(UADebugSDKModule)
public class DebugSDKModule : NSObject, SDKModule {
    public static func load(withDependencies dependencies: [AnyHashable : Any]) -> SDKModule? {
        let analytics = dependencies[SDKDependencyKeys.analytics] as! Analytics
        AirshipDebug.takeOff(analytics)
        return nil
    }
}
