/* Copyright Airship and Contributors */

import Foundation

/**
 * Action that produces an empty result.
 */
@objc(UAEmptyAction)
public class EmptyAction : NSObject, UAAction {
    
    /**
     * Default constructor.
     */
    @objc
    public override init() {
        super.init()
    }
    

    public func acceptsArguments(_ arguments: UAActionArguments) -> Bool {
        return true
    }
    
    public func perform(with arguments: UAActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        completionHandler(UAActionResult.empty())
    }
}
