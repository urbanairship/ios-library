/* Copyright Airship and Contributors */

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
            UAAction *action = [entry actionForSituation:situation];
            [action runWithArguments:arguments completionHandler:completionHandler];
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
@end
