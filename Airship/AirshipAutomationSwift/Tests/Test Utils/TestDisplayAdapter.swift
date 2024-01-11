/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable import AirshipAutomationSwift
@testable import AirshipCore

final class TestDisplayAdapter: DisplayAdapter, @unchecked Sendable {
    @MainActor
    var isReady: Bool = true

    @MainActor
    func waitForReady() async {
        
    }

    @MainActor
    var onDisplay: ((WindowSceneHolder, InAppMessageAnalyticsProtocol) async -> Void)?

    @MainActor
    var displayed: Bool = false

    @MainActor
    func display(scene: WindowSceneHolder, analytics: InAppMessageAnalyticsProtocol) async {
        await self.onDisplay!(scene, analytics)
        self.displayed = true
    }
}
