/* Copyright Airship and Contributors */

import Foundation

/**
 * Action that produces an empty result.
 */
@objc(UAEmptyAction)
public class EmptyAction : NSObject, Action {
    
    /**
     * Default constructor.
     */
    @objc
    public override init() {
        super.init()
    }
    

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        return true
    }
    
    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        completionHandler(ActionResult.empty())
    }
}
