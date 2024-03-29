/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable import AirshipAutomation
@testable import AirshipCore

final class TestDisplayAdapter: DisplayAdapter, @unchecked Sendable {
    @MainActor
    var isReady: Bool = true

    @MainActor
    func waitForReady() async {
        
    }

    @MainActor
    var onDisplay: ((WindowSceneHolder, InAppMessageAnalyticsProtocol) async throws -> DisplayResult)?

    @MainActor
    var displayed: Bool = false

    @MainActor
    func display(scene: WindowSceneHolder, analytics: InAppMessageAnalyticsProtocol) async throws -> DisplayResult {
        self.displayed = true
        return try await self.onDisplay!(scene, analytics)
    }
}
