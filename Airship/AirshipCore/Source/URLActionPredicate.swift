/* Copyright Airship and Contributors */

/**
 * Default predicate for URL actions.
 */
@objc(UAURLActionPredicate)
public class URLActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.situation != .foregroundPush
    }
}


