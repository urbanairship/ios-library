/* Copyright Airship and Contributors */

/**
 * Default predicate for the add custom event action.
 */
@objc(UAAddCustomEventActionPredicate)
public class AddCustomEventActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}
