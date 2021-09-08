/* Copyright Airship and Contributors */

/**
 * Default predicate for the modify attributes action.
 */
@objc(UAAttributesActionPredicate)
public class AttributesActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}
