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
#import "UAActionAggregatedResult.h"

@implementation UAActionRunner


+ (void)performActionWithArguments:(UAActionArguments *)arguments
             withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    UAActionEntry *entry = [[UAActionRegistrar shared].registeredEntries valueForKey:arguments.name];
    if (!entry || (entry.predicate && !entry.predicate(arguments))) {
        completionHandler(nil);
    } else {
        [entry.action performWithArguments:arguments withCompletionHandler:completionHandler];
    }
}

+ (void)performAction:(NSString *)name
        withSituation:(NSString *)situation
            withValue:(id)value
          withPayload:(NSDictionary *)payload
withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    UAActionArguments *args = [UAActionArguments argumentsWithName:name
                                                     withSituation:situation
                                                         withValue:value
                                                       withPayload:payload];

    [self performActionWithArguments:args withCompletionHandler:completionHandler];
}

+ (void)performActionsFromDictionary:(NSDictionary *)actionDictionary
                       withSituation:(NSString *)situation
                         withPayload:(NSDictionary *)payload
               withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    if (!actionDictionary || !actionDictionary.count) {
        completionHandler(nil);
        return;
    }

    __block int expectedCount = actionDictionary.count;
    __block int resultCount = 0;

    __block UAActionAggregatedResult *aggregatedResult = [[UAActionAggregatedResult alloc] init];

    for (NSString *name in actionDictionary) {

        __block BOOL completionHandlerCalled = NO;
        UAActionCompletionHandler intermediateCompletionHandler = ^(UAActionResult *result) {
            @synchronized(self) {
                if (completionHandlerCalled) {
                    UA_LERR(@"Action %@ completion handler called multiple times.", name);
                    return;
                }

                resultCount ++;

                if (result) {
                    [aggregatedResult addResult:result];
                }
                
                if (expectedCount == resultCount && completionHandler) {
                    completionHandler(aggregatedResult);
                }
            }
        };

        [self performAction:name
              withSituation:situation
                  withValue:[actionDictionary valueForKey:name]
                withPayload:actionDictionary
      withCompletionHandler:intermediateCompletionHandler];
    }
}



@end
