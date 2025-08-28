/* Copyright Airship and Contributors */


import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

// Internal display adapter
protocol DisplayAdapter: Sendable {
    @MainActor
    var isReady: Bool { get }

    func waitForReady() async

    @MainActor
    func display(
        scene: any WindowSceneHolder,
        analytics: any InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult
}

enum DisplayResult: Sendable, Equatable {
    case cancel
    case finished
}
