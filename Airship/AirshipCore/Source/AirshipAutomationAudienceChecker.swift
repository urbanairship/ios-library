import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAAutomationAudienceChecker)
public class AirshipAutomationAudienceChecker: NSObject, AirshipAutomationAudienceCheckerProtocol {

    @objc
    public func evaluate(audience: Any, isNewUserEvaluationDate: Date, contactID: String?) async throws -> Bool {
        let audienceData = try JSONSerialization.data(withJSONObject: audience)
        let parsedAudience = try JSONDecoder().decode(DeviceAudienceSelector.self, from: audienceData)

        return try await parsedAudience.evaluate(
            newUserEvaluationDate: isNewUserEvaluationDate,
            contactID: contactID
        )
    }
}

@objc(UAAutomationAudienceCheckerProtocol)
public protocol AirshipAutomationAudienceCheckerProtocol {
    func evaluate(audience: Any, isNewUserEvaluationDate: Date, contactID: String?) async throws -> Bool
}

