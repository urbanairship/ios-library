import Foundation

import AirshipCore

struct DeferredScheduleResult: Sendable, Codable, Equatable {
    var isAudienceMatch: Bool
    var message: InAppMessage?
    var actions: AirshipJSON?

    /// AI suppression config resolved server side. When present it replaces the
    /// schedule's `ai_suppression`, letting the deferred response add suppression
    /// to a schedule that has none or tailor the condition per resolution.
    var aiSuppression: AutomationAISuppression?

    enum CodingKeys: String, CodingKey {
        case isAudienceMatch = "audience_match"
        case message
        case actions
        case aiSuppression = "ai_suppression"
    }
}
