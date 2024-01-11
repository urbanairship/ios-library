/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Wraps a custom display adapter as a DisplayAdapter
final class CustomDisplayAdapterWrapper: DisplayAdapter {
    let adapter: CustomDisplayAdapter

    var isReady: Bool { return adapter.isReady }

    func waitForReady() async {
        await adapter.waitForReady()
    }

    init(adapter: CustomDisplayAdapter) {
        self.adapter = adapter
    }

    func display(scene: WindowSceneHolder, analytics: InAppMessageAnalyticsProtocol) async {
        // TODO: Wire up analytics
        await self.adapter.display(scene: scene.scene)
    }
}
