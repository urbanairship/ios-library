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

@implementation UAActionRunner

/*

+ (void)performActionWithArguments:(id)arguments
             withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    UAAction *action = [[UAActionRegistrar shared] actionForName:arguments]
    UAActionEntry *entry = [[UAActionRegistrar shared].registeredEntries valueForKey:arguments.name];
    if (!entry || (entry.predicate && !entry.predicate(arguments))) {
        completionHandler([UAActionResult resultWithObject:nil withArguments:arguments]);
    } else {
        [entry.action performWithArguments:arguments withCompletionHandler:completionHandler];
    }
}

+ (void)performAction:(NSString *)name
        withSituation:(NSString *)situation
            withValue:(id)value
          withPayload:(NSDictionary *)payload
withCompletionHandler:(UAActionBaseCompletionHandler)completionHandler {

    UAActionArguments *args = [UAActionArguments argumentsWithName:name
                                                     withSituation:situation
                                                         withValue:value
                                                       withPayload:payload];

    [self performActionWithArguments:args withCompletionHandler:completionHandler];
}

+ (void)performActionsForNotification:(NSDictionary *)notification
                      inSituation:(NSString *)situation
            withCompletionHandler:(UAActionBaseCompletionHandler)completionHandler {

    NSDictionary *notificationActions = [notification objectForKey:@"actions"];

    __block int expectedCount = notificationActions.count;
    __block int resultCount = 0;
    __block UAActionFetchResult currentFetchResult = UAActionFetchResultNoData;

    for (NSString *name in notificationActions) {

        __block BOOL completionHandlerCalled = NO;
        UAActionBaseCompletionHandler intermediateCompletionHandler = ^(UAActionResult *result) {
            @synchronized(self) {
                if (completionHandlerCalled) {
                    UA_LERR(@"Action %@ completion handler called multiple times.", name);
                    return;
                }

                resultCount ++;

                currentFetchResult = [UAAction combineActionFetchResult:currentFetchResult
                                               withResult:result.fetchResult];

                if (expectedCount == resultCount && completionHandler) {
                    UAActionResult *finalResult = [UAActionResult resultWithObject:nil withArguments:result.arguments];
                    completionHandler(finalResult);
                }
            }
        };

        [self performAction:name
              withSituation:situation
                  withValue:[notificationActions valueForKey:name]
                withPayload:notification
      withCompletionHandler:intermediateCompletionHandler];
    }
}
*/ 
@end
