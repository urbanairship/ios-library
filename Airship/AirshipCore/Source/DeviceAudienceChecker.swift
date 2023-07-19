import Foundation


public protocol DeviceAudienceChecker: Sendable {
    func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        contactID: String?
    ) async throws -> Bool

    func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        contactID: String?,
        deviceInfoProvider: AudienceDeviceInfoProvider
    ) async throws -> Bool
}


public struct DefaultDeviceAudienceChecker: DeviceAudienceChecker {
    public init() {}
    
    public func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        contactID: String?
    ) async throws -> Bool {
        return try await evaluate(
            audience: audience,
            newUserEvaluationDate: newUserEvaluationDate,
            contactID: contactID,
            deviceInfoProvider: DefaultAudienceDeviceInfoProvider()
        )
    }

    public func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        contactID: String?,
        deviceInfoProvider: AudienceDeviceInfoProvider
    ) async throws -> Bool {
        return try await audience.evaluate(
            newUserEvaluationDate: newUserEvaluationDate,
            contactID: contactID,
            deviceInfoProvider: deviceInfoProvider
        )
    }
}
