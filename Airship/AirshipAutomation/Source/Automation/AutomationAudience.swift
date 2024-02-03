import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Automation device audience
public struct AutomationAudience: Codable, Sendable, Equatable {

    /// Miss behavior when the audience is not a match
    public enum MissBehavior: String, Codable, Sendable {
        /// Cancel the schedule
        case cancel
        /// Skip the execution
        case skip
        /// Skip the execution but count towards the limit
        case penalize
    }

    let audienceSelector: DeviceAudienceSelector
    let missBehavior: MissBehavior?

    enum CodingKeys: String, CodingKey {
        case missBehavior = "miss_behavior"
    }

    public init(
        audienceSelector: DeviceAudienceSelector,
        missBehavior: MissBehavior? = nil
    ) {
        self.audienceSelector = audienceSelector
        self.missBehavior = missBehavior
    }

    public func encode(to encoder: Encoder) throws {
        try audienceSelector.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.missBehavior, forKey: .missBehavior)
    }

    public init(from decoder: Decoder) throws {
        self.audienceSelector = try DeviceAudienceSelector(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.missBehavior = try container.decodeIfPresent(AutomationAudience.MissBehavior.self, forKey: .missBehavior)
    }
}


