/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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
#import "UAAction.h"
#import "UAActionRegistry.h"
#import "UAAggregateActionResult.h"

NS_ASSUME_NONNULL_BEGIN

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
 * @param value The action's argument value.
 * @param situation The action's situation.
 */
+ (void)runActionWithName:(NSString *)actionName
                    value:(nullable id)value
                situation:(UASituation)situation;

/**
 * Runs a registered action with the given name.
 *
 * If the action is not registered the completion handler
 * will be called immediately with [UAActionResult emptyResult]
 *
 * @param actionName The name of the action to run
 * @param value The action's argument value.
 * @param situation The action's situation.
 * @param metadata The action's metadata.
 */
+ (void)runActionWithName:(NSString *)actionName
                    value:(nullable id)value
                situation:(UASituation)situation
                 metadata:(NSDictionary *)metadata;

/**
 * Runs a registered action with the given name.
 *
 * If the action is not registered the completion handler
 * will be called immediately with [UAActionResult emptyResult]
 *
 * @param actionName The name of the action to run
 * @param value The action's argument value.
 * @param situation The action's situation.
 * @param completionHandler Optional completion handler to run when the action completes.
 */
+ (void)runActionWithName:(NSString *)actionName
                    value:(nullable id)value
                situation:(UASituation)situation
        completionHandler:(UAActionCompletionHandler)completionHandler;

/**
 * Runs a registered action with the given name.
 *
 * If the action is not registered the completion handler 
 * will be called immediately with [UAActionResult emptyResult]
 *
 * @param actionName The name of the action to run
 * @param value The action's argument value.
 * @param situation The action's situation.
 * @param metadata The action's metadata.
 * @param completionHandler Optional completion handler to run when the action completes.
 */
+ (void)runActionWithName:(NSString *)actionName
                value:(nullable id)value
            situation:(UASituation)situation
             metadata:(nullable NSDictionary *)metadata
    completionHandler:(nullable UAActionCompletionHandler)completionHandler;



/**
 * Runs an action.
 *
 * @param action The action to run
 * @param value The action's argument value.
 * @param situation The action's situation.
 */
+ (void)runAction:(UAAction *)action
            value:(nullable id)value
        situation:(UASituation)situation;

/**
 * Runs an action.
 *
 * @param action The action to run
 * @param value The action's argument value.
 * @param situation The action's situation.
 * @param metadata The action's metadata.
 */
+ (void)runAction:(UAAction *)action
            value:(nullable id)value
        situation:(UASituation)situation
         metadata:(nullable NSDictionary *)metadata;

/**
 * Runs an action.
 *
 * @param action The action to run
 * @param value The action's argument value.
 * @param situation The action's situation.
 * @param completionHandler Optional completion handler to run when the action completes.
 */
+ (void)runAction:(UAAction *)action
            value:(nullable id)value
        situation:(UASituation)situation
completionHandler:(UAActionCompletionHandler)completionHandler;


/**
 * Runs an action.
 *
 * @param action The action to run
 * @param value The action's argument value.
 * @param situation The action's situation.
 * @param metadata The action's metadata.
 * @param completionHandler Optional completion handler to run when the action completes.
 */
+ (void)runAction:(UAAction *)action
            value:(nullable id)value
        situation:(UASituation)situation
         metadata:(nullable NSDictionary *)metadata
completionHandler:(nullable UAActionCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
