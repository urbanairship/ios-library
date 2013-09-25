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
 * If the action is not registered the completion handler 
 * will be called immedietly with [UAActionResult none]
 *
 * @param actionName The name of the action to perform
 * @param argument The action's argument.
 * @param completionHandler CompletionHandler to pass to the action.
 */
+ (void)performAction:(NSString *)actionName
         withArgument:(UAPushActionArguments *)argument
withCompletionHandler:(UAActionCompletionHandler)completionHandler;


/**
 * Performs any actions defined in the notificaiton.
 *
 * @param notification The notification.
 * @param applicationState The state of the application.
 * @param completionHandler CompletionHandler to run after all the 
 * actions have completed.  The result will be the aggregated result 
 * of all the actions performed.
 */
+ (void)performActionsForNotification:(NSDictionary *)notification
                 withApplicationState:(UIApplicationState)applicationState
                withCompletionHandler:(UAActionCompletionHandler)completionHandler;

@end
