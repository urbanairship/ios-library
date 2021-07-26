/* Copyright Airship and Contributors */

#import "UAActionRunner.h"
#import "UAActionRegistryEntry.h"
#import "UAActionResult+Internal.h"
#import "UAirship.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif


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
    [self runActionWithEntry:entry value:value situation:situation metadata:metadata completionHandler:completionHandler];
}

+ (void)runActionWithEntry:(UAActionRegistryEntry *)entry
                     value:(id)value
                 situation:(UASituation)situation
                  metadata:(NSDictionary *)metadata
         completionHandler:(UAActionCompletionHandler)completionHandler {
    if (entry) {
        // Add the action name to the metadata
        NSMutableDictionary *fullMetadata = metadata ? [NSMutableDictionary dictionaryWithDictionary:metadata] : [NSMutableDictionary dictionary];
        fullMetadata[UAActionMetadataRegisteredName] = [entry.names firstObject];

        UAActionArguments *arguments = [UAActionArguments argumentsWithValue:value withSituation:situation metadata:fullMetadata];
        if (!entry.predicate || entry.predicate(arguments)) {
            id<UAAction> action = [entry actionForSituation:situation];
            [self runAction:action args:arguments completionHandler:completionHandler];
        } else {
            UA_LDEBUG(@"Not running action %@ because of predicate.", [entry.names firstObject]);
            if (completionHandler) {
                completionHandler([UAActionResult rejectedArgumentsResult]);
            }
        }
    } else {
        UA_LDEBUG(@"No action found with name %@, skipping action.", [entry.names firstObject]);
        if (completionHandler) {
            completionHandler([UAActionResult actionNotFoundResult]);
        }
    }
}


+ (void)runAction:(id<UAAction>)action
            value:(id)value
        situation:(UASituation)situation {

    [self runAction:action value:value situation:situation metadata:nil completionHandler:nil];
}

+ (void)runAction:(id<UAAction>)action
            value:(id)value
        situation:(UASituation)situation
         metadata:(NSDictionary *)metadata {

    [self runAction:action value:value situation:situation metadata:metadata completionHandler:nil];
}

+ (void)runAction:(id<UAAction>)action
            value:(id)value
        situation:(UASituation)situation
completionHandler:(UAActionCompletionHandler)completionHandler {

    [self runAction:action value:value situation:situation metadata:nil completionHandler:completionHandler];
}

+ (void)runAction:(id<UAAction>)action
            value:(id)value
        situation:(UASituation)situation
         metadata:(NSDictionary *)metadata
completionHandler:(UAActionCompletionHandler)completionHandler {

    UAActionArguments *arguments = [UAActionArguments argumentsWithValue:value withSituation:situation metadata:metadata];
    [self runAction:action args:arguments completionHandler:completionHandler];
}

+ (void)runActionsWithActionValues:(NSDictionary *)actionValues
                         situation:(UASituation)situation
                          metadata:(NSDictionary *)metadata
                 completionHandler:(UAActionCompletionHandler)completionHandler {

    __block UAAggregateActionResult *aggregateResult = [[UAAggregateActionResult alloc] init];
    __block NSUInteger dispatchGroupEnterCount = 0;
    __block NSUInteger dispatchGroupLeaveCount = 0;

    if (!actionValues.count) {
        UA_LTRACE("No actions to perform.");
        if (completionHandler) {
            completionHandler(aggregateResult);
        }
        return;
    }

    dispatch_group_t dispatchGroup = dispatch_group_create();

    NSMutableSet *actionEntries = [NSMutableSet set];
    for (NSString *actionName in actionValues) {
        UAActionRegistryEntry *entry = [[UAirship shared].actionRegistry registryEntryWithName:actionName];
        if (entry) {
            [actionEntries addObject:entry];
        }
    }

    for (UAActionRegistryEntry *entry in actionEntries) {
        __block NSUInteger completions = 0;
        UAActionCompletionHandler handler = ^(UAActionResult *result) {
            @synchronized(self) {
                completions++;
                if (completions > 1) {
                    UA_LWARN(@"Multiple completion handler calls detected for action: %@. ", entry.names.firstObject);
                } else {
                    [aggregateResult addResult:result forAction:entry.names.firstObject];
                }

                if (dispatchGroupLeaveCount < dispatchGroupEnterCount) {
                    dispatch_group_leave(dispatchGroup);
                }

                dispatchGroupLeaveCount++;
            }
        };

        dispatch_group_enter(dispatchGroup);
        dispatchGroupEnterCount++;

        id value;
        for (NSString *name in entry.names) {
            id val = actionValues[name];
            if (val) {
                value = val;
            }
        }

        [self runActionWithEntry:entry
                           value:value
                       situation:situation
                        metadata:metadata
               completionHandler:handler];
    }
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        // all action(s) have run
        completionHandler(aggregateResult);
    });
}

+ (void)runAction:(id<UAAction>)action
             args:(UAActionArguments *)arguments
completionHandler:(UAActionCompletionHandler)completionHandler {

    // If no completion handler was passed, use an empty block in its place
    completionHandler = completionHandler ?: ^(UAActionResult *result) {};
    
    // Make sure the initial acceptsArguments/willPerform/perform is executed on the main queue
    [UADispatcher.main dispatchAsyncIfNecessary:^{
        if (![action acceptsArguments:arguments]) {
            UA_LDEBUG(@"Action %@ rejected arguments %@.", [self description], [arguments description]);
            completionHandler([UAActionResult rejectedArgumentsResult]);
        } else {
            UA_LDEBUG(@"Action %@ performing with arguments %@.", [self description], [arguments description]);
            
            if ([action respondsToSelector:@selector(willPerformWithArguments:)]) {
                [action willPerformWithArguments:arguments];
            }
            
            [action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
                // Make sure the passed completion handler and didPerformWithArguments are executed on the main queue
                [UADispatcher.main dispatchAsyncIfNecessary:^{
                    if (!result) {
                        UA_LTRACE("Action %@ called the completion handler with a nil result", [self description]);
                    }

                    UAActionResult *normalizedResult = result ?: [UAActionResult emptyResult];
                    
                    if ([action respondsToSelector:@selector(didPerformWithArguments:withResult:)]) {
                        [action didPerformWithArguments:arguments withResult:normalizedResult];
                    }
                    
                    completionHandler(normalizedResult);
                }];
            }];
        }
    }];
}


@end
