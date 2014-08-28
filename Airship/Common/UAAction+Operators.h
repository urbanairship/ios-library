/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAAction.h"

/**
 * Represents the possible error conditions when running an action.
 */
typedef NS_ENUM(NSInteger, UAActionOperatorErrorCode) {
    /**
     * Indicates the action rejected the arguments.
     */
    UAActionOperatorErrorCodeChildActionRejectedArgs
};

/**
 * The domain for errors encountered during an action operator.
 */
extern NSString * const UAActionOperatorErrorDomain;

/**
 * A block that defines work that can be done before the action is performed.
 */
typedef void (^UAActionPreExecutionBlock)(UAActionArguments *);

/**
 * A block that defines work that can be done after the action is performed, before the final completion handler is called.
 */
typedef void (^UAActionPostExecutionBlock)(UAActionArguments *, UAActionResult *);

/**
 * A block that defines a means of merging two UAActionResult instances into one value.
 */
typedef UAActionResult * (^UAActionFoldResultsBlock)(UAActionResult *, UAActionResult *);

/**
 * A block that defines a means of tranforming one UAActionArguments to another
 */
typedef UAActionArguments * (^UAActionMapArgumentsBlock)(UAActionArguments *);

/**
 * A block defining a monadic bind operation.
 */
typedef UAAction * (^UAActionBindBlock)(UAActionBlock, UAActionPredicate);

/**
 * A block defining a monadic lift operation on the action block
 */
typedef UAActionBlock (^UAActionLiftBlock)(UAActionBlock);

/**
 * A block defining a monadic lift operation on the predicate block
 */
typedef UAActionPredicate (^UAActionPredicateLiftBlock)(UAActionPredicate);


@interface UAAction (Operators)

/**
 * Operator for creating a monadic binding.
 *
 * @param bindBlock A UAActionBindBlock
 * @return A new UAAction wrapping the receiver and binding the passed block.
 */
- (UAAction *)bind:(UAActionBindBlock)bindBlock;

/**
 * Operator for lifting a block transforming an action block and predicate, into a monadic binding.
 *
 * @param actionLiftBlock A UAActionLiftBlock
 * @param predicateLiftBlock A UAActionPredicteLiftBlock
 * @return A new UAAction wrapping the receiver, which lifts the passed blocks into a bind operation.
 */
- (UAAction *)lift:(UAActionLiftBlock)actionLiftBlock transformingPredicate:(UAActionPredicateLiftBlock)predicateLiftBlock;

/**
 * Operator for lifting a block transforming an action block, into a monadic binding.
 *
 * @param liftBlock A UAActionLiftBlock
 * @return A new UAAction wrapping the receiver, which lifts the passed block into a bind operation.
 */
- (UAAction *)lift:(UAActionLiftBlock)liftBlock;

/**
 * Operator for chaining two actions together in sequence.
 *
 * When run, if the receiver executes normally, the result will be passed in the
 * arguments to the supplied continuation action, whose result will be passed in the
 * completion handler as the final result.
 *
 * Otherwise if the receiver action rejects its arguments or
 * encounters an error, the continuation will finish early and the receiver's result
 * will be passed in the completion handler.
 *
 * The result of the aggregate action is the result of the second action.
 *
 * @param continuationAction A UAAction to be executed as the continuation of
 * the receiver.
 * @return A new UAAction wrapping the receiver and the continuationAction, which chains
 * the two together when run.
 */
- (UAAction *)continueWith:(UAAction *)continuationAction;

/**
 * Operator for limiting the scope of an action with a predicate block.
 *
 * This operator serves the same purpose as the [UAAction acceptsArguments:] method, but
 * can be used to customize an action ad-hoc without deriving a subclass.
 *
 * @param filterBlock A UAActionPredicate block.
 * @return A new UAAction wrapping the receiver and applying the supplied filterBlock to its argument validation logic.
 */
- (UAAction *)filter:(UAActionPredicate)filterBlock;

/**
 * Operator for transforming the arguments passed into an action.
 *
 * @param mapArgumentsBlock A UAActionMapArgumentsBlock
 * @return A new UAAction wrapping the receiver and applying the supplied mapArgumentsBlock as a transformation on the arguments.
 */
- (UAAction *)map:(UAActionMapArgumentsBlock)mapArgumentsBlock;

/**
 * Operator for adding additional pre-execution logic to an action.
 *
 * This operator serves the same purpose as [UAAction willPerformWithArguments:] but
 * can be used to customize an action ad-hoc without deriving a subclass.
 *
 * @param preExecutionBlock A UAActionPreExecutionBlock.
 * @return A new UAAction wrapping the receiver that executes the preExecutionBlock when run, before performing.
 */
- (UAAction *)preExecution:(UAActionPreExecutionBlock)preExecutionBlock;

/**
 * Operator for adding additional post-execution logic to an action.
 *
 * This operator serves the same purpose as [UAAction didPerformWithArguments:withResult:] but
 * can be used to customize an action ad-hoc without deriving a subclass.
 *
 * @param postExecutionBlock A UAActionPostExecutionBlock.
 * @return A new UAAction wrapping the receiver that executes the postExecutionBlock when run, before performing.
 */
- (UAAction *)postExecution:(UAActionPostExecutionBlock)postExecutionBlock;

@end
