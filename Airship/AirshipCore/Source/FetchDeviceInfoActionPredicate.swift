/* Copyright Airship and Contributors */

/**
 * Default predicate for the fetch device info action.
 */
@objc(UAFetchDeviceInfoActionPredicate)
public class FetchDeviceInfoActionPredicate : NSObject, UAActionPredicateProtocol {
    public func apply(_ args: UAActionArguments) -> Bool {
        return args.situation == .manualInvocation || args.situation == .webViewInvocation
    }
}


