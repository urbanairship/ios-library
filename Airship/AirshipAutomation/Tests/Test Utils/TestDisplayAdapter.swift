/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable import AirshipAutomation
@testable import AirshipCore

@MainActor
final class TestDisplayAdapter: DisplayAdapter, @unchecked Sendable {
    var isReady: Bool = true

    func waitForReady() async {
        
    }

    var onDisplay: ((any WindowSceneHolder, any InAppMessageAnalyticsProtocol) async throws -> DisplayResult)?

    var displayed: Bool = false

    func display(scene: any WindowSceneHolder, analytics: any InAppMessageAnalyticsProtocol) async throws -> DisplayResult {
        self.displayed = true
        return try await self.onDisplay!(scene, analytics)
    }
}
