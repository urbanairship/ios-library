/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) public import AirshipCore

/// AirshipAIModels module loader. Registers the default on-device model with
/// the Core AI manager when the module is linked.
/// - Note: For internal use only. :nodoc:
@objc(UAAIModelsSDKModule)
@_spi(AirshipInternal)
public class AirshipAIModelsSDKModule: NSObject, AirshipSDKModule {

    public let actionsManifest: (any ActionsManifest)? = nil
    public let components: [any AirshipComponent] = []

    @MainActor
    public static func load(_ args: AirshipModuleLoaderArgs) -> (any AirshipSDKModule)? {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            args.aiManager.registerModelFactory {
                return SystemAIModel()
            }
        }
#endif
        return AirshipAIModelsSDKModule()
    }
}
