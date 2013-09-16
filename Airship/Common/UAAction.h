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

@class UAAction;

/**
 * A custom predicate block that can be used to limit the scope of an action.
 */
typedef BOOL (^UAActionPredicate)(id);

/**
 * A custom predicate block that can be used to limit the scope of an action.
 */
typedef id (^UAActionFoldResultsBlock)(id, id);

/**
 * A completion handler that singals that an action has finished executing.
 */

typedef void (^UAActionCompletionHandler)(id);

/**
 * A block that defines the work performed by an action.
 */
typedef void (^UAActionBlock)(id, UAActionCompletionHandler completionHandler);

/**
 * A unit of work that can be associated with a push notification.
 */
@interface UAAction : NSObject

/**
 * Operator for defining anonymous actions
 *
 * @param actionBlock A UAActionBlock representing the work performed by the action.
 */

+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock;

/**
 * Operator for limiting the scope of actions with a predicate.
 *
 * @param predicateBlock A UAActionPredicate block.
 */
- (instancetype)actionWithPredicate:(UAActionPredicate)predicateBlock;

/**
 * Operator for creating an action that strings together two separate actions,
 * passing the result of the first as the argument of the second.
 *
 * The result of the aggregate action is the result of the second action.
 *
 * @param continuationAction A UAAction to be executed as the continuation of
 * the receiver.
 */
- (instancetype)actionWithContinuationAction:(UAAction *)continuationAction;

- (instancetype)actionFoldingAction:(UAAction *)foldedAction withFoldBlock:(UAActionFoldResultsBlock)foldBlock;

/**
 * Triggers the action. Subclasses of UAAction should override this method to define custom behavior.
 *
 * @param arguments An id value representing the arguments passed to the action.
 * @param completionHandler A UAActionCompletionHandler that will be called when the action has finished executing.
 */
- (void)performWithArguments:(id)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler;

@end
