/* Copyright Airship and Contributors */

import Foundation


// NOTE: For internal use only. :nodoc:
public protocol AirshipSDKModule: NSObject {
    var actionsManifest: ActionsManifest? { get }
    var components: [AirshipComponent] { get }

    @MainActor
    static func load(dependencies: [String: Any]) -> AirshipSDKModule?
}
