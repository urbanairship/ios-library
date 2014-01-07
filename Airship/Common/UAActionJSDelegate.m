
#import "UAActionJSDelegate.h"
#import "UAGlobal.h"

#import "NSJSONSerialization+UAAdditions.h"
#import "NSString+URLEncoding.h"

#import "UAActionRunner.h"
#import "UAWebViewCallData.h"

@implementation UAActionJSDelegate

/**
 * Returns an action matching a URL-encoded name.
 *
 * @param name A URL-encoded action name.
 * @return A UAAction registered for that name, or nil if decoding or retrieval fails.
 *
 */
- (UAAction *)actionForEncodedName:(NSString *)name {
    NSString *decodedName = [name urlDecodedStringWithEncoding:NSUTF8StringEncoding];
    if (!decodedName) {
        UA_LDEBUG(@"unable to url decode action name: %@", name);
    }
    UAAction *action = [[UAActionRegistrar shared] registryEntryWithName:decodedName].action;

    if (!action) {
        UA_LDEBUG(@"no registry entry found for action name: %@", decodedName);
    } else {
        UA_LDEBUG(@"action name: %@", decodedName);
    }
    return action;
}

/**
 * Returns a foundation object matching a JSON and URL-encoded argument string.
 *
 * @param arguments A JSON and URL-encoded string representing an action argument.
 * @return A foundation object decoded from the passed string, or nil if decoding fails.
 */
- (id)objectForEncodedArguments:(NSString *)arguments {
    NSString *urlDecodedArgs = [arguments urlDecodedStringWithEncoding:NSUTF8StringEncoding];
    if (!urlDecodedArgs) {
        UA_LDEBUG(@"unable to url decode action args: %@", arguments);
        return nil;
    }
    //allow the reading of fragments so we can parse lower level JSON values
    id jsonDecodedArgs = [NSJSONSerialization objectWithString:urlDecodedArgs
                                                       options: NSJSONReadingMutableContainers | NSJSONReadingAllowFragments];
    if (!jsonDecodedArgs) {
        UA_LDEBUG(@"unable to json decode action args: %@", urlDecodedArgs);
    } else {
        UA_LDEBUG(@"action arguments value: %@", jsonDecodedArgs);
    }
    return jsonDecodedArgs;
}

/**
 * Handles the run-action JS callback.
 *
 * This supports async callbacks into JS functions, as well the passing of
 * arbitrary argument objects through JSON serialization of core types.  It is best
 * used from JavaScript, but can be used entirely through URL loading as well.
 *
 * @param callbackID A callback identifier generated in the JS layer. This can be nil.
 * @param options The options passed in the JS delegate callback.
 * @param completionHandler The completion handler passed in the JS delegate callback.
 */
- (void)runActionWithCallbackID:(NSString *)callbackID
                    withOptions:(NSDictionary *)options
       withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {
    NSArray *keys = [options allKeys];

    NSString *actionName = [keys firstObject];

    if (!actionName) {
        UA_LDEBUG(@"no action name was passed");
        return;
    }

    UAAction *action = [self actionForEncodedName:actionName];
    NSString *encodedArgumentsValue = [options valueForKey:actionName];
    id decodedArgumentsValue;
    if (encodedArgumentsValue) {
        decodedArgumentsValue = [self objectForEncodedArguments:encodedArgumentsValue];
    }

    //if we found an action by that name, and there's either no argument or a correctly decoded argument
    if (action && (decodedArgumentsValue || !encodedArgumentsValue)) {
        UAActionArguments *actionArgs = [UAActionArguments argumentsWithValue:decodedArgumentsValue
                                                                withSituation:UASituationRichPushAction];
        [UAActionRunner runAction:action withArguments:actionArgs withCompletionHandler:^(UAActionResult *result){
            if (result.error){
                UA_LDEBUG(@"action %@ completed with an error", actionName);
                if (callbackID) {
                    //pass the error description back into JS wrapped in an Error object
                    NSString *script = [NSString stringWithFormat:@"var err = new Error('%@');UAirship.finishAction(err, null, '%@');",
                                        result.error.localizedDescription,
                                        callbackID];
                    completionHandler(script);
                }
            } else {
                UA_LDEBUG(@"action %@ completed successfully", actionName);
                if (callbackID) {
                    NSString *resultString;
                    if (result.value) {
                        //if the action completed with a result value, serialize into JSON
                        //accepting fragments so we can write lower level JSON values
                        resultString = [NSJSONSerialization stringWithObject:result.value acceptingFragments:YES];
                    }
                    //in the case where there is no result value, pass null
                    resultString = resultString ?: @"null";
                    //note: JSON.parse('null') and JSON.parse(null) are functionally equivalent.
                    NSString *script = [NSString stringWithFormat:@"UAirship.finishAction(null, '%@', '%@');", resultString, callbackID];
                    completionHandler(script);
                } else {
                    completionHandler(nil);
                }
            }
        }];
    } else {
        //we'll probably eventually want to pass different kinds of errors
        if (callbackID) {
            NSString *errorString;
            if (!action) {
                errorString = [NSString stringWithFormat:@"Unable to retrieve action named: %@", actionName];
            } else if (!decodedArgumentsValue) {
                errorString = [NSString stringWithFormat:@"Error decoding arguments: %@", encodedArgumentsValue];
            }
            NSString *script = [NSString stringWithFormat:@"UAirship.finishAction(new Error('%@'), null, '%@');", errorString, callbackID];
            completionHandler(script);
        } else {
            completionHandler(nil);
        }
    }
}

/**
 * Handles the run-basic-action callback.
 *
 * This does not support callbacks into the JS layer, and only allows
 * for passing string arguments to actions.  For convenience, multiple actions can
 * be passed in the query options, in which case they will all be run at once.
 *
 * @param options The options passed in the JS delegate callback.
 * @param completionHandler The completion handler passed in the JS delegate callback.
 */
- (void)runBasicActionWithOptions:(NSDictionary *)options
         withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {

    for (NSString *actionName in options) {
        UAAction *action = [self actionForEncodedName:actionName];
        NSString *encodedArgumentsValue = [options objectForKey:actionName];
        NSString *decodedArgumentsValue = [encodedArgumentsValue urlDecodedStringWithEncoding:NSUTF8StringEncoding];

        UAActionArguments *actionArgs = [UAActionArguments argumentsWithValue:decodedArgumentsValue withSituation:UASituationRichPushAction];

        //if we found an action by that name, and there's either no argument or a correctly decoded argument
        if (action && (!encodedArgumentsValue || decodedArgumentsValue)) {
            [UAActionRunner runAction:action withArguments:actionArgs withCompletionHandler:^(UAActionResult *result){
                if (result.error) {
                    UA_LDEBUG(@"action %@ completed with an error", actionName);
                } else {
                    UA_LDEBUG(@"action %@ completed successfully", actionName);
                }
            }];
        }
    }

    completionHandler(nil);
}

- (void)callWithData:(UAWebViewCallData *)data
    withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {
    UA_LDEBUG(@"action js delegate arguments: %@ \n options: %@", data.arguments, data.options);

    //we need at least one argument
    //run-action is the full js/callback interface
    if ([data.name isEqualToString:@"run-action"]) {
        //the callbackID is optional, if present we can make an async callback
        //into the JS environment, otherwise we'll just run the action to completion

        NSString *callbackID = [data.arguments firstObject];
        [self runActionWithCallbackID:callbackID
                          withOptions:data.options
                withCompletionHandler:completionHandler];
    } else if ([data.name isEqualToString:@"run-basic-action"]) {
        //run-basic-action is the 'demo-friendly' version with implicit string argument values and
        //allows multiple simultaneous actions
        [self runBasicActionWithOptions:data.options withCompletionHandler:completionHandler];
    } else {
        //arguments not recognized, pass a nil script result
        completionHandler(nil);
    }
}

@end
