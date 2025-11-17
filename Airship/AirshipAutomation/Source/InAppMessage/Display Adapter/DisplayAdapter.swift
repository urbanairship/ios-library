/* Copyright Airship and Contributors */

import Foundation
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
        displayTarget: AirshipDisplayTarget,
        analytics: any InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult
}

enum DisplayResult: Sendable, Equatable {
    case cancel
    case finished
}
