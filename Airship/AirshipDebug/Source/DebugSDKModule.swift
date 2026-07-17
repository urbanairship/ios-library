/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) public import AirshipCore

nonisolated(unsafe) var debugModuleAIManager: (any AirshipAI.InternalManager)?

/// - Note: For internal use only. :nodoc:
@objc(UADebugSDKModule)
@_spi(AirshipInternal)
public final class DebugSDKModule: NSObject, AirshipSDKModule {

    public var actionsManifest: (any ActionsManifest)? = nil

    public let components: [any AirshipComponent]

    public static func load(_ args: AirshipModuleLoaderArgs) -> (any AirshipSDKModule)? {
        debugModuleAIManager = args.aiManager
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
