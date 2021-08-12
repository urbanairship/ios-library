/* Copyright Airship and Contributors */

/**
 * Default predicate for the enable feature action.
 */
@objc(UAEnableFeatureActionPredicate)
public class EnableFeatureActionPredicate : NSObject, UAActionPredicateProtocol {
    public func apply(_ args: UAActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}

