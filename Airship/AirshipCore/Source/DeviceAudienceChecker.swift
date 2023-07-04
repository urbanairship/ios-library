import Foundation


protocol DeviceAudienceChecker: Sendable {
    func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        contactID: String?
    ) async throws -> Bool
}


struct DefaultDeviceAudienceChecker: DeviceAudienceChecker {
    func evaluate(audience: DeviceAudienceSelector, newUserEvaluationDate: Date, contactID: String?) async throws -> Bool {
        return try await audience.evaluate(newUserEvaluationDate: newUserEvaluationDate, contactID: contactID)
    }
}
