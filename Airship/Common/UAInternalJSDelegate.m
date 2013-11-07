
#import "UAInternalJSDelegate.h"
#import "UAGlobal.h"

#import "NSString+URLDecoding.h"

#import "UAActionRunner.h"

@implementation UAInternalJSDelegate

- (UAAction *)actionForEncodedName:(NSString *)name {
    NSString *decodedName = [name urlDecodedStringWithEncoding:NSUTF8StringEncoding];
    if (!decodedName) {
        UA_LDEBUG(@"unable to url decode action name: %@", name);
    }
    UAAction *action = [[UAActionRegistrar shared] registryEntryForName:decodedName].action;
    if (!action) {
        UA_LDEBUG(@"no registry entry found for action name: %@", decodedName);
    } else {
        UA_LDEBUG(@"action name: %@", decodedName);
    }
    return action;
}

- (id)objectForEncodedArguments:(NSString *)arguments {
    NSString *urlDecodedArgs = [arguments urlDecodedStringWithEncoding:NSUTF8StringEncoding];
    if (!urlDecodedArgs) {
        UA_LDEBUG(@"unable to url decode action args: %@", arguments);
        return nil;
    }
    //use NSJSONSerialization directly here, so we can allow the reading of fragments
    id jsonDecodedArgs = [NSJSONSerialization JSONObjectWithData: [urlDecodedArgs dataUsingEncoding:NSUTF8StringEncoding]
                                                          options: NSJSONReadingMutableContainers | NSJSONReadingAllowFragments
                                                            error: nil];
    if (!jsonDecodedArgs) {
        UA_LDEBUG(@"unable to to json decode action args: %@", urlDecodedArgs);
    } else {
        UA_LDEBUG(@"action arguments value: %@", jsonDecodedArgs);
    }
    return jsonDecodedArgs;
}

- (void)callbackArguments:(NSArray *)args
                    withOptions:(NSDictionary *)options
          withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {
    UA_LDEBUG(@"internal js delegate arguments: %@ \n options: %@", args, options);

    if (args.count && [[args objectAtIndex:0] isEqualToString:@"run-action"]) {

        NSArray *keys = [options allKeys];
        NSMutableArray *actions = [NSMutableArray array];

        BOOL hasError = NO;

        for (NSString *actionName in keys) {
            UAAction *action = [self actionForEncodedName:actionName];
            NSString *encodedArgumentsValue = [options valueForKey:actionName];
            id decodedArgumentsValue;
            if (encodedArgumentsValue) {
                decodedArgumentsValue = [self objectForEncodedArguments:encodedArgumentsValue];
            }

            //we have enough to work with as long as there's an action to run, and either no encoded args
            //or properly decoded args
            if (action && (decodedArgumentsValue || !encodedArgumentsValue)) {
                UAActionArguments *actionArgs = [UAActionArguments argumentsWithValue:decodedArgumentsValue
                                                                        withSituation:UASituationRichPushAction];
                [actions addObject:@[action, actionArgs]];
            } else {
                hasError = YES;
            }
        }

        NSString *script = nil;
        if (!hasError) {
            for (NSArray *pair in actions) {
                UAAction *action = [pair objectAtIndex:0];
                UAActionArguments *args = [pair objectAtIndex:1];

                [UAActionRunner runAction:action withArguments:args withCompletionHandler:^(UAActionResult *result){
                    UA_LINFO(@"Action completed");
                }];
            }
            script = @"UAListener.result = 'Callback from ObjC succeeded'; UAListener.onSuccess();";
        } else {
            script = @"UAListener.error = 'Callback from ObjC failed'; UAListener.onError();";
        }
        completionHandler(script);
    }

    completionHandler(nil);
}

@end
