import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Automation compound audience
public struct AutomationCompoundAudience: Codable, Sendable, Equatable {
    let selector: CompoundDeviceAudienceSelector
    let missBehavior: AutomationAudience.MissBehavior
    
    enum CodingKeys: String, CodingKey {
        case selector = "selector"
        case missBehavior = "miss_behavior"
    }
    
    /// Automation compound audience initialized
    /// - Parameters:
    ///   - audienceSelector: The audience selector
    ///   - missBehavior: Behavior when audience selector is not a match
    public init(
        selector: CompoundDeviceAudienceSelector,
        missBehavior: AutomationAudience.MissBehavior
    ) {
        self.selector = selector
        self.missBehavior = missBehavior
    }
}
