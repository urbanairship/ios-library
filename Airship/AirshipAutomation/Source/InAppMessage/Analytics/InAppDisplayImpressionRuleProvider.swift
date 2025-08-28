/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

enum InAppDisplayImpressionRule: Equatable, Sendable {
    case once
    case interval(TimeInterval)
}

protocol InAppDisplayImpressionRuleProvider: Sendable {
    func impressionRules(for message: InAppMessage) -> InAppDisplayImpressionRule
}

final class DefaultInAppDisplayImpressionRuleProvider: InAppDisplayImpressionRuleProvider  {
    private static let defaultEmbeddedImpressionInterval: TimeInterval = 1800.0 // 30 mins

    func impressionRules(for message: InAppMessage) -> InAppDisplayImpressionRule {
        if (message.isEmbedded) {
            return .interval(Self.defaultEmbeddedImpressionInterval)
        } else {
            return .once
        }
    }
}
