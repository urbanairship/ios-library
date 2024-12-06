/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol DeviceAudienceChecker: Sendable {
    func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> Bool
}

/// NOTE: For internal use only. :nodoc:
public struct DefaultDeviceAudienceChecker: DeviceAudienceChecker {
    public init() {}

    public func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> Bool {
        return try await audience.evaluate(
            newUserEvaluationDate: newUserEvaluationDate,
            deviceInfoProvider: deviceInfoProvider
        )
    }
}
