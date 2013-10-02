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
#import "UAAction+Internal.h"
#import "UAAggregateActionResult.h"
#import "UAActionRegistryEntry.h"

@implementation UAActionRunner

+ (void)runActionWithName:(NSString *)actionName
                withArguments:(UAActionArguments *)arguments
        withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    UAActionRegistryEntry *entry = [[UAActionRegistrar shared].registeredActionEntries valueForKey:actionName];

    if (entry) {
        if (entry.predicate && entry.predicate(arguments)) {
            UA_LINFO("Running action %@", actionName);
            [self runAction:entry.action withArguments:arguments withCompletionHandler:completionHandler];
        }
    } else {
        UA_LINFO("No action found with name %@, skipping action.", actionName);
        completionHandler([UAActionResult none]);
    }
}

+ (void)runAction:(UAAction *)action
    withArguments:(UAActionArguments *)arguments
withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    [action runWithArguments:arguments withCompletionHandler:completionHandler];
}

+ (void)runActions:(NSDictionary *)actions
 withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    if (!actions.count) {
        UA_LTRACE("No actions to perform.");
        return;
    }

    __block NSUInteger expectedCount = actions.count;
    __block NSUInteger resultCount = 0;
    __block UAAggregateActionResult *aggregateResult = [[UAAggregateActionResult alloc] init];

    for (NSString *actionName in actions) {
        __block BOOL completionHandlerCalled = NO;

        UAActionCompletionHandler handler = ^(UAActionResult *result) {
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

        UAActionArguments *args = [actions objectForKey:actionName];

        [self runActionWithName:actionName
                      withArguments:args withCompletionHandler:handler];
    }
}
@end
