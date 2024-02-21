/* Copyright Airship and Contributors */
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

/// - Note: For internal use only. :nodoc:
@objc(UADebugSDKModule)
public class DebugSDKModule: NSObject, AirshipSDKModule {

    public var actionsManifest: ActionsManifest? = nil

    public let components: [AirshipComponent]

    public static func load(dependencies: [String : Any]) -> AirshipSDKModule? {
        let analytics = dependencies[SDKDependencyKeys.analytics] as! AirshipAnalyticsProtocol
        let remoteData = dependencies[SDKDependencyKeys.remoteData] as! RemoteDataProtocol
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
