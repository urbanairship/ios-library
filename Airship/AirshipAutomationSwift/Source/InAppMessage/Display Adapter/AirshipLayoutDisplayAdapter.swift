/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

final class AirshipLayoutDisplayAdapter: DisplayAdapter {

    private let message: InAppMessage
    private let assets: AirshipCachedAssetsProtocol
    private let networkChecker: NetworkCheckerProtocol

    init(
        message: InAppMessage,
        assets: AirshipCachedAssetsProtocol,
        networkChecker: NetworkCheckerProtocol = NetworkChecker()
    ) throws {
        self.message = message
        self.assets = assets
        self.networkChecker = networkChecker

        if case .custom(_) = message.displayContent {
            throw AirshipErrors.error("Invalid adapter for layout type")
        }
    }

    var isReady: Bool {
        let urlInfos = message.urlInfos
        let needsNetwork = urlInfos.contains { info in
            guard
                info.urlType == .image,
                let url = URL(string: info.url),
                assets.isCached(remoteURL: url)
            else {
                return true
            }
            return false
        }

        return needsNetwork ? networkChecker.isConnected : true
    }

    func waitForReady() async {
        guard await !self.isReady else {
            return
        }

        for await isConnected in await networkChecker.connectionUpdates {
            if (isConnected) {
                return
            }
        }
    }

    func display(scene: WindowSceneHolder, analytics: InAppMessageAnalyticsProtocol) async {
       // TODO display
    }
}

