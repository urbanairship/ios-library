/* Copyright Airship and Contributors */

@testable
import AirshipCore

import Foundation

final class TestExperimentDataProvider: ExperimentDataProvider, @unchecked Sendable {
    var onEvaluate: ((MessageInfo, AudienceDeviceInfoProvider) async throws -> ExperimentResult?)? = nil

    func evaluateExperiments(
        info: MessageInfo,
        deviceInfoProvider: AudienceDeviceInfoProvider
    ) async throws -> ExperimentResult? {
        return try await onEvaluate?(info, deviceInfoProvider)
    }
}
