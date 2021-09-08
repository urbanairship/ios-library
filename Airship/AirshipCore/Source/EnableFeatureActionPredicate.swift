/* Copyright Airship and Contributors */

/**
 * Default predicate for the enable feature action.
 */
@objc(UAEnableFeatureActionPredicate)
public class EnableFeatureActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}

