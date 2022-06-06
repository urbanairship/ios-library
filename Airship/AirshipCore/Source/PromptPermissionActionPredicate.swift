/* Copyright Airship and Contributors */

/**
 * Default predicate for the prompt permission action.
 */
@objc(UAPromptPermissionActionPredicate)
public class PromptPermissionActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.metadata?[UAActionMetadataForegroundPresentationKey] == nil
    }
}

