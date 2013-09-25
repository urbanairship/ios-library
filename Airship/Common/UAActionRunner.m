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

#import "UAActionRunner.h"
#import "UAAggregateActionResult.h"

@implementation UAActionRunner

+ (void)performAction:(NSString *)actionName
         withArgument:(id)argument
withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    UAAction *action = [[UAActionRegistrar shared] actionForName:actionName];

    if (action) {
        UA_LINFO("Running action %@", actionName);
        [action performWithArguments:argument withCompletionHandler:completionHandler];
    } else {
        UA_LINFO("No action found with name %@, skipping action.", actionName);
        completionHandler([UAActionResult none]);
    }
}

+ (void)performActionsForNotification:(NSDictionary *)notification
                 withApplicationState:(UIApplicationState)state
                withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    NSDictionary *notificationActions = [notification objectForKey:@"actions"];

    __block int expectedCount = notificationActions.count;
    __block int resultCount = 0;
    __block UAAggregateActionResult *aggregateResult = [[UAAggregateActionResult alloc] init];

    for (__block NSString *actionName in notificationActions) {
        __block BOOL completionHandlerCalled = NO;

        __block UAPushActionArguments *arg = [UAPushActionArguments argumentsWithName:actionName
                                                                withApplicationState:state
                                                                            withValue:[notificationActions valueForKey:actionName]
                                                                          withPayload:notification];

        UAActionCompletionHandler intermediateCompletionHandler = ^(UAActionResult *result) {
            @synchronized(self) {
                if (completionHandlerCalled) {
                    UA_LERR(@"Action %@ completion handler called multiple times.", actionName);
                    return;
                }

                resultCount ++;

                [aggregateResult addResult:result forAction:actionName];

                if (expectedCount == resultCount && completionHandler) {
                    completionHandler(aggregateResult);
                }
            }
        };

        [self performAction:actionName
               withArgument:arg withCompletionHandler:intermediateCompletionHandler];
    }
}

@end
