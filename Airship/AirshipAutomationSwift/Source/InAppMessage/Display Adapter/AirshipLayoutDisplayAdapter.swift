/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

final class AirshipLayoutDisplayAdapter: DisplayAdapter {
    func waitForReady() async {
        
    }
    
    let content: InAppMessageDisplayContent
    let assets: AirshipCachedAssetsProtocol

    init(content: InAppMessageDisplayContent, assets: AirshipCachedAssetsProtocol) throws {
        self.content = content
        self.assets = assets

        if case .custom(_) = content {
            throw AirshipErrors.error("Invalid adapter for layout type")
        }
    }

    var isReady: Bool {
        /// TODO: if it has an uncached asset needs network
        return true
    }

    func display(scene: WindowSceneHolder, analytics: InAppMessageAnalyticsProtocol) async {
        /// TODO display
    }

}
