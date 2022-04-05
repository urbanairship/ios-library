/* Copyright Airship and Contributors */

/**
 * Default predicate for subscription list actions.
 */
@available(tvOS, unavailable)
@objc(UASubscriptionListActionPredicate)
public class SubscriptionListActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}


