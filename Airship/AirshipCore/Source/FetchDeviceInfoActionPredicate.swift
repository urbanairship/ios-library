/* Copyright Airship and Contributors */

/**
 * Default predicate for the fetch device info action.
 */
@objc(UAFetchDeviceInfoActionPredicate)
public class FetchDeviceInfoActionPredicate : NSObject, ActionPredicateProtocol {
    public func apply(_ args: ActionArguments) -> Bool {
        return args.situation == .manualInvocation || args.situation == .webViewInvocation
    }
}


