import Foundation

#if canImport(AirshipCore)
public import AirshipCore
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

    /// Automation audience initialized
    /// - Parameters:
    ///   - audienceSelector: The audience selector
    ///   - missBehavior: Behavior when audience selector is not a match
    public init(
        audienceSelector: DeviceAudienceSelector,
        missBehavior: MissBehavior? = nil
    ) {
        self.audienceSelector = audienceSelector
        self.missBehavior = missBehavior
    }

    public func encode(to encoder: any Encoder) throws {
        try audienceSelector.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.missBehavior, forKey: .missBehavior)
    }

    public init(from decoder: any Decoder) throws {
        self.audienceSelector = try DeviceAudienceSelector(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.missBehavior = try container.decodeIfPresent(AutomationAudience.MissBehavior.self, forKey: .missBehavior)
    }
}

struct AdditionalAudienceCheckOverrides: Codable, Sendable, Equatable {
    let bypass: Bool?
    let context: AirshipJSON?
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case bypass, context, url
    }
}

extension AutomationAudience.MissBehavior {
    var schedulePrepareResult: SchedulePrepareResult {
        switch self {
        case .cancel: return .cancel
        case .penalize: return .penalize
        case .skip: return .skip
        }
    }
}


