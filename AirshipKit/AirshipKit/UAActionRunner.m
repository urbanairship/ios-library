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

#import "UAActionRunner.h"
#import "UAAction+Internal.h"
#import "UAActionRegistryEntry.h"
#import "UAActionResult+Internal.h"
#import "UAirship.h"

NSString * const UAActionRunnerErrorDomain = @"com.urbanairship.actions.runner";

@implementation UAActionRunner

+ (void)runActionWithName:(NSString *)actionName
                    value:(id)value
                situation:(UASituation)situation {

    [self runActionWithName:actionName value:value situation:situation metadata:nil completionHandler:nil];
}

+ (void)runActionWithName:(NSString *)actionName
                    value:(id)value
                situation:(UASituation)situation
                 metadata:(NSDictionary *)metadata {

    [self runActionWithName:actionName value:value situation:situation metadata:metadata completionHandler:nil];
}

+ (void)runActionWithName:(NSString *)actionName
                    value:(id)value
                situation:(UASituation)situation
        completionHandler:(UAActionCompletionHandler)completionHandler {

    [self runActionWithName:actionName value:value situation:situation metadata:nil completionHandler:completionHandler];
}

+ (void)runActionWithName:(NSString *)actionName
                    value:(id)value
                situation:(UASituation)situation
                 metadata:(NSDictionary *)metadata
        completionHandler:(UAActionCompletionHandler)completionHandler {

    UAActionRegistryEntry *entry = [[UAirship shared].actionRegistry registryEntryWithName:actionName];


    if (entry) {
        // Add the action name to the metadata
        NSMutableDictionary *fullMetadata = metadata ? [NSMutableDictionary dictionaryWithDictionary:metadata] : [NSMutableDictionary dictionary];
        fullMetadata[UAActionMetadataRegisteredName] = actionName;

        UAActionArguments *arguments = [UAActionArguments argumentsWithValue:value withSituation:situation metadata:fullMetadata];
        if (!entry.predicate || entry.predicate(arguments)) {
            UAAction *action = [entry actionForSituation:situation];
            [action runWithArguments:arguments completionHandler:completionHandler];
        } else {
            UA_LDEBUG(@"Not running action %@ because of predicate.", actionName);
            if (completionHandler) {
                completionHandler([UAActionResult rejectedArgumentsResult]);
            }
        }
    } else {
        UA_LDEBUG(@"No action found with name %@, skipping action.", actionName);

        //log a warning if the name begins with a carat prefix.
        if ([actionName hasPrefix:@"^"]) {
            UA_LWARN(@"Extra names beginning with the carat (^) character are reserved by Urban Airship \
                     and may be subject to future use.");
        }

        if (completionHandler) {
            completionHandler([UAActionResult actionNotFoundResult]);
        }
    }
}


+ (void)runAction:(UAAction *)action
            value:(id)value
        situation:(UASituation)situation {

    [self runAction:action value:value situation:situation metadata:nil completionHandler:nil];
}

+ (void)runAction:(UAAction *)action
            value:(id)value
        situation:(UASituation)situation
         metadata:(NSDictionary *)metadata {

    [self runAction:action value:value situation:situation metadata:metadata completionHandler:nil];
}

+ (void)runAction:(UAAction *)action
            value:(id)value
        situation:(UASituation)situation
completionHandler:(UAActionCompletionHandler)completionHandler {

    [self runAction:action value:value situation:situation metadata:nil completionHandler:completionHandler];
}

+ (void)runAction:(UAAction *)action
            value:(id)value
        situation:(UASituation)situation
         metadata:(NSDictionary *)metadata
completionHandler:(UAActionCompletionHandler)completionHandler {

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:value withSituation:situation metadata:metadata];
    [action runWithArguments:arguments completionHandler:completionHandler];
}

+ (void)runActionsWithActionValues:(NSDictionary *)actionValues
                         situation:(UASituation)situation
                          metadata:(NSDictionary *)metadata
                 completionHandler:(UAActionCompletionHandler)completionHandler {

    __block UAAggregateActionResult *aggregateResult = [[UAAggregateActionResult alloc] init];
    __block NSUInteger expectedCount = actionValues.count;
    __block NSUInteger resultCount = 0;

    if (!actionValues.count) {
        UA_LTRACE("No actions to perform.");
        if (completionHandler) {
            completionHandler(aggregateResult);
        }
        return;
    }

    for (NSString *actionName in actionValues) {
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

        [self runActionWithName:actionName
                          value:actionValues[actionName]
                      situation:situation
                       metadata:metadata
              completionHandler:handler];
    }
}
@end
