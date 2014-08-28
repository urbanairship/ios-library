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

#import <Foundation/Foundation.h>
#import "UAAction.h"
#import "UAActionRegistry.h"
#import "UAAggregateActionResult.h"

/**
 * A helper class for running actions by name or by reference.
 */
@interface UAActionRunner : NSObject

/**
 * Runs a registered action with the given name.
 *
 * If the action is not registered the completion handler 
 * will be called immediately with [UAActionResult emptyResult]
 *
 * @param actionName The name of the action to run
 * @param arguments The action's arguments
 * @param completionHandler CompletionHandler to pass to the action.
 */
+ (void)runActionWithName:(NSString *)actionName
                withArguments:(UAActionArguments *)arguments
        withCompletionHandler:(UAActionCompletionHandler)completionHandler;

/**
 * Runs an action.
 *
 * @param action The action to run
 * @param arguments The action's arguments
 * @param completionHandler CompletionHandler to pass to the action.
 */
+ (void)runAction:(UAAction *)action
    withArguments:(UAActionArguments *)arguments
withCompletionHandler:(UAActionCompletionHandler)completionHandler;

/**
 * Runs a map of actionNames and action arguments.
 *
 * The results of all the actions will be aggregated into a 
 * single UAAggregateActionResult.
 *
 * @param actions The map of action names and arguments.
 * @param completionHandler CompletionHandler to call after all the
 * actions have completed. The result will be the aggregated result
 * of all the actions run.
 */
+ (void)runActions:(NSDictionary *)actions
 withCompletionHandler:(UAActionCompletionHandler)completionHandler;

@end
