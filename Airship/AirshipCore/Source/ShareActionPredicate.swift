/* Copyright Airship and Contributors */

/**
 * Default predicate for the share action.
 */
@available(tvOS, unavailable)
@objc(UAShareActionPredicate)
public class ShareActionPredicate : NSObject, UAActionPredicateProtocol {
    public func apply(_ args: UAActionArguments) -> Bool {
        return args.situation != .foregroundPush
    }
}
