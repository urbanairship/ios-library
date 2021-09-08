/* Copyright Airship and Contributors */

/**
 * Default predicate for the tag actions.
 */
@available(tvOS, unavailable)
@objc(UATagsActionPredicate)
public class TagsActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}


