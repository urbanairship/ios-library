/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

#import <Foundation/Foundation.h>
#import "UAActionResult.h"
#import "UAActionArguments.h"


@class UAAction;

/**
 * A custom block that can be used to limit the scope of an action.
 */
typedef BOOL (^UAActionPredicate)(UAActionArguments *);

/**
 * A block that defines a means of merging two UAActionResult intsances into one value.
 */
typedef UAActionResult * (^UAActionFoldResultsBlock)(UAActionResult *, UAActionResult *);

/**
 * A completion handler that singals that an action has finished executing.
 */

typedef void (^UAActionCompletionHandler)(UAActionResult *);

/**
 * A block that defines the primary work performed by an action.
 */
typedef void (^UAActionBlock)(UAActionArguments *, UAActionCompletionHandler completionHandler);

/**
 * A simple void/void block typedef.
 */
typedef void (^UAActionVoidBlock)();

/**
 * A block that defines work that can be done before the action is performed.
 */
typedef void (^UAActionPreExecutionBlock)(UAActionArguments *);

/**
 * A block that defines work that can be done after the action is performed, before the final completion handler is called.
 */
typedef void (^UAActionPostExecutionBlock)(UAActionArguments *, UAActionResult *);

/**
 * Base class for actions, which define a modular unit of work.
 */
@interface UAAction : NSObject

#pragma mark core methods

/**
 * Called before an action is performed to determine if the
 * the action can accept the arguments.
 *
 * This method can be used both to verify that an argument's value is an appropriate type,
 * as well as to limit the scope of execution of a desired range of values.  Rejecting
 * argumets will result in the action not being performed when it is run.
 *
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 * @return YES if the action can perform with the arguments, otherwise NO
 */
- (BOOL)acceptsArguments:(UAActionArguments *)arguments;

/**
 * Called before the action's performWithArguments:withCompletionHandler:
 *
 * This method can be used to define optional setup or pre-execution logic.
 *
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 */
- (void)willPerformWithArguments:(UAActionArguments *)arguments;

/**
 * Called after the action is performed, before its final complention handler is called.
 *
 * This method can be used to define optional teardown or post-execution logic.
 *
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 * @param result A UAActionResult from performing the action.
 */
- (void)didPerformWithArguments:(UAActionArguments *)arguments withResult:(UAActionResult *)result;

/**
 * Perfroms the action. 
 *
 * Subclasses of UAAction should override this method to define custom behavior.
 *
 * @note You should not ordinarily call this method directly.  Instead, use the `UAActionRunner`.
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 * @param completionHandler A UAActionCompletionHandler that will be called when the action has finished executing.
 */
- (void)performWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler;

#pragma mark factory methods

/**
 * Factory method for creating anonymous actions
 *
 * @param actionBlock A UAActionBlock representing the primary work performed by the action.
 */
+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock;

#pragma mark operators

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
- (instancetype)continueWith:(UAAction *)continuationAction;

/**
 * Operator for limiting the scope of an action with a predicate block.
 *
 * This operator serves the same purpose as the [UAAction acceptsArguments:] method, but
 * can be used to customize an action ad-hoc without deriving a subclass.
 *
 * @param filterBlock A UAActionPredicate block.
 * @return A new UAAction wrapping the receiver and applying the supplied filterBlock to its argument validation logic.
 */
- (instancetype)filter:(UAActionPredicate)filterBlock;

/**
 * Operator for adding additional pre-execution logic to an action.
 *
 * This operator serves the same purpose as [UAAction willPerformWithArguments:] but
 * can be used to customize an action ad-hoc without deriving a subclass.
 *
 * @param preExecutionBlock A UAActionPreExecutionBlock.
 * @return A new UAAction wrapping the receiver that executes the preExecutionBlock when run, before performing.
 */
- (instancetype)preExecution:(UAActionPreExecutionBlock)preExecutionBlock;

/**
 * Operator for adding additional post-execution logic to an action.
 *
 * This operator serves the same purpose as [UAAction didPerformWithArguments:withResult:] but
 * can be used to customize an action ad-hoc without deriving a subclass.
 *
 * @param preExecutionBlock A UAActionPostExecutionBlock.
 * @return A new UAAction wrapping the receiver that executes the postExecutionBlock when run, before performing.
 */
- (instancetype)postExecution:(UAActionPostExecutionBlock)postExecutionBlock;

/**
 * Operator for limiting the number of times an action can be performed.
 *
 * @param n The number of times the action should be performed. After this
 * count has been reached, running the action will no longer have any effect.
 * @return A new UAAction wrapping the reciever with the supplied restrictions in place.
 */
- (instancetype)take:(NSUInteger)n;

/**
 * Operator for skipping execution in an initial number of runs.
 *
 * @param n The number of times the action should skip performing. Until this
 * count has been reached, running the action will not have any effect.
 * @return A new UAAction wrapping the reciever with the supplied restrictions in place.
 */
- (instancetype)skip:(NSUInteger)n;

/**
 * Operator for limiting execution to an nth run.
 *
 * @param n The nth run on which the action should be performed, if and only
 * this count has been reached. Otherwise, running the action will not have any effect.
 * @return A new UAAction wrapping the reciever with the supplied restrictions in place.
 */
- (instancetype)nth:(NSUInteger)n;

@end
