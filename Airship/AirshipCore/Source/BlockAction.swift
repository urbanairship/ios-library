/* Copyright Airship and Contributors */

import Foundation

/**
 * Action that runs a block.
 * - Note: For internal use only. :nodoc:
 */
@objc(UABlockAction)
public class BlockAction : NSObject, Action {
    private let block: UAActionBlock;
    private let predicate: UAActionPredicate?;
    
    /**
     * Block action constructor.
     *  - Parameters:
     *    - predicate: Optional predicate.
     *    - block: The action block.
     */
    @objc
    public init(predicate: UAActionPredicate?, block: @escaping UAActionBlock) {
        self.predicate = predicate
        self.block = block
        super.init()
    }
    
    /**
     * Block action constructor.
     *  - Parameters:
     *    - block: The action block.
     */
    @objc(initWithBlock:)
    public convenience init(_ block: @escaping UAActionBlock) {
        self.init(predicate: nil, block: block)
    }

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        return self.predicate?(arguments) ?? true
    }
    
    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        self.block(arguments, completionHandler)
    }
}
