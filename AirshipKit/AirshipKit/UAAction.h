/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

NS_ASSUME_NONNULL_BEGIN

/**
 * A custom block that can be used to limit the scope of an action.
 */
typedef BOOL (^UAActionPredicate)(UAActionArguments *);

/**
 * A completion handler that signals that an action has finished executing.
 */
typedef void (^UAActionCompletionHandler)(UAActionResult *);

/**
 * A block that defines the primary work performed by an action.
 */
typedef void (^UAActionBlock)(UAActionArguments *, UAActionCompletionHandler completionHandler);

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
 * as well as to limit the scope of execution of a desired range of values. Rejecting
 * arguments will result in the action not being performed when it is run.
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
 * Called after the action has performed, before its final completion handler is called.
 *
 * This method can be used to define optional teardown or post-execution logic.
 *
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 * @param result A UAActionResult from performing the action.
 */
- (void)didPerformWithArguments:(UAActionArguments *)arguments
                     withResult:(UAActionResult *)result;


/**
 * Performs the action.
 *
 * Subclasses of UAAction should override this method to define custom behavior.
 *
 * @note You should not ordinarily call this method directly. Instead, use the `UAActionRunner`.
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 * @param completionHandler A UAActionCompletionHandler that will be called when the action has finished executing.
 */
- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler;

#pragma mark factory methods

/**
 * Factory method for creating anonymous actions
 *
 * @param actionBlock A UAActionBlock representing the primary work performed by the action.
 */
+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock;

/**
 * Factory method for creating anonymous actions
 *
 * @param actionBlock A UAActionBlock representing the primary work performed by the action.
 * @param predicateBlock A UAActionPredicate limiting the scope of the arguments.
 */
+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock
             acceptingArguments:(nullable UAActionPredicate)predicateBlock;

@end

NS_ASSUME_NONNULL_END
