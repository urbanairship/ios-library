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
#import "UAAction.h"
#import "UAActionRegistrar.h"
#import "UAPushActionArguments.h"


@interface UAActionRunner : NSObject

/**
 * Performs a registered action with the given name.
 *
 * If the action is not registered or if the predicate prevents
 * the action from running, the completion handler will be called
 * immediately with UAActionResultNoData.
 *
 * @param name Name of the action to perform.
 * @param situation Situation to perform the action in.
 * @param value The value.
 * @param payload The payload.
 * @param completionHandler CompletionHandler to pass to the action.
 */



+ (void)performAction:(NSString *)name
        withSituation:(NSString *)situation
            withValue:(id)value
          withPayload:(NSDictionary *)payload
withCompletionHandler:(UAActionCompletionHandler)completionHandler;


/**
 * Performs a registered action with the given name.
 *
 * If the action is not registered or if the predicate prevents
 * the action from running, the completion handler will be called
 * immediately with UAActionResultNoData.
 *
 * @param arguments The arguments for the action to perform
 * @param completionHandler CompletionHandler to pass to the action.
 */
+ (void)performActionWithArguments:(UAPushActionArguments *)arguments
             withCompletionHandler:(UAActionCompletionHandler)completionHandler;


/**
 * Performs any actions defined in the notificaiton.
 *
 * @param notification The notification.
 * @param situation The situation of the action.
 * @param completionHandler CompletionHandler to run after all the 
 * actions have completed.  The result will be the aggregated result 
 * of all the actions performed.
 */
+ (void)performActionsForNotification:(NSDictionary *)notification
                          inSituation:(NSString *)situation
                withCompletionHandler:(UAActionCompletionHandler)completionHandler;

@end
