/* Copyright Urban Airship and Contributors */

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

    if (!actionValues.count) {
        UA_LTRACE("No actions to perform.");
        if (completionHandler) {
            completionHandler(aggregateResult);
        }
        return;
    }

    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    for (NSString *actionName in actionValues) {
        __block BOOL completionHandlerCalled = NO;

        UAActionCompletionHandler handler = ^(UAActionResult *result) {
            @synchronized(self) {
                if (completionHandlerCalled) {
                    UA_LTRACE(@"Action %@ completion handler called multiple times.", actionName);
                    dispatch_group_leave(dispatchGroup);
                    return;
                }
                completionHandlerCalled = YES;
                
                [aggregateResult addResult:result forAction:actionName];
                
                dispatch_group_leave(dispatchGroup);
            }
        };

        dispatch_group_enter(dispatchGroup);
        [self runActionWithName:actionName
                          value:actionValues[actionName]
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
