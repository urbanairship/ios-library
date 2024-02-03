import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct DeferredScheduleResult: Sendable, Codable, Equatable {
    var isAudienceMatch: Bool
    var message: InAppMessage?
    var actions: AirshipJSON?

    enum CodingKeys: String, CodingKey {
        case isAudienceMatch = "audience_match"
        case message
        case actions
    }
}
