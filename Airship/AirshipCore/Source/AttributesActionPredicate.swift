/* Copyright Airship and Contributors */

/**
 * Default predicate for the modify attributes action.
 */
@objc(UAAttributesActionPredicate)
public class AttributesActionPredicate : NSObject, UAActionPredicateProtocol {
    public func apply(_ args: UAActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}
