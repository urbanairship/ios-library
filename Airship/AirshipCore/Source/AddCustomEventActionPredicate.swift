/* Copyright Airship and Contributors */

/**
 * Default predicate for the add custom event action.
 */
@objc(UAAddCustomEventActionPredicate)
public class AddCustomEventActionPredicate : NSObject, UAActionPredicateProtocol {
    public func apply(_ args: UAActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}
