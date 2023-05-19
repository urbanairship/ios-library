/* Copyright Airship and Contributors */
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

@objc(UADebugSDKModule)
public class DebugSDKModule: NSObject, SDKModule {
    private let debugManager: AirshipDebugManager

    public init(_ debugManager: AirshipDebugManager) {
        self.debugManager = debugManager
    }

    public func components() -> [Component] {
        return [self.debugManager]
    }

    public static func load(withDependencies dependencies: [AnyHashable: Any])
        -> SDKModule?
    {
        let analytics = dependencies[SDKDependencyKeys.analytics] as! AirshipAnalytics
        let remoteData =
            dependencies[SDKDependencyKeys.remoteData] as! RemoteDataProtocol
        let config = dependencies[SDKDependencyKeys.config] as! RuntimeConfig

        let debugManager = AirshipDebugManager(
            config: config,
            analytics: analytics,
            remoteData: remoteData
        )
        return DebugSDKModule(debugManager)
    }
}
