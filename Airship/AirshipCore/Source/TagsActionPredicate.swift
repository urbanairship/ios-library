/* Copyright Airship and Contributors */

/**
 * Default predicate for the tag actions.
 */
@available(tvOS, unavailable)
@objc(UATagsActionPredicate)
public class TagsActionPredicate : NSObject, UAActionPredicateProtocol {
    public func apply(_ args: UAActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}


