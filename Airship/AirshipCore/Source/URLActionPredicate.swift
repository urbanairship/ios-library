/* Copyright Airship and Contributors */

/**
 * Default predicate for URL actions.
 */
@objc(UAURLActionPredicate)
public class URLActionPredicate : NSObject, UAActionPredicateProtocol {
    public func apply(_ args: UAActionArguments) -> Bool {
        return args.situation != .foregroundPush
    }
}


