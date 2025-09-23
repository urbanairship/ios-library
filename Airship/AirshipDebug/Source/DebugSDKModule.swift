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

    public static func load(_ args: AirshiopModuleLoaderArgs) -> (any AirshipSDKModule)? {
        let debugManager = DefaultAirshipDebugManager(
            config: args.config,
            analytics: args.analytics,
            remoteData: args.remoteData
        )
        return DebugSDKModule(debugManager)
    }

    private init(_ debugManager: any InternalAirshipDebugManager) {
        self.components = [DebugComponent(debugManager: debugManager)]
    }
}
