/* Copyright Airship and Contributors */
import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

/// - Note: For internal use only. :nodoc:
@objc(UADebugSDKModule)
public class DebugSDKModule: NSObject, AirshipSDKModule {

    public var actionsManifest: (any ActionsManifest)? = nil

    public let components: [any AirshipComponent]

    public static func load(dependencies: [String : Any]) -> (any AirshipSDKModule)? {
        let analytics = dependencies[SDKDependencyKeys.analytics] as! (any AirshipAnalyticsProtocol)
        let remoteData = dependencies[SDKDependencyKeys.remoteData] as! (any RemoteDataProtocol)
        let config = dependencies[SDKDependencyKeys.config] as! RuntimeConfig

        let debugManager = AirshipDebugManager(
            config: config,
            analytics: analytics,
            remoteData: remoteData
        )
        return DebugSDKModule(debugManager)
    }

    private init(_ debugManager: AirshipDebugManager) {
        self.components = [DebugComponent(debugManager: debugManager)]
    }
}
