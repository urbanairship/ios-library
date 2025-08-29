/* Copyright Airship and Contributors */

import Foundation


/// NOTE: For internal use only. :nodoc:
public protocol AirshipSDKModule: NSObject {
    var actionsManifest: (any ActionsManifest)? { get }
    var components: [any AirshipComponent] { get }

    @MainActor
    static func load(_ args: AirshiopModuleLoaderArgs) -> (any AirshipSDKModule)?
}
