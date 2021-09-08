/* Copyright Airship and Contributors */

/**
 * Default predicate for the share action.
 */
@available(tvOS, unavailable)
@objc(UAShareActionPredicate)
public class ShareActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.situation != .foregroundPush
    }
}
