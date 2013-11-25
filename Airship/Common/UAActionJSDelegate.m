
#import "UAActionJSDelegate.h"
#import "UAGlobal.h"

#import "NSJSONSerialization+UAAdditions.h"
#import "NSString+URLEncoding.h"

#import "UAActionRunner.h"

@implementation UAActionJSDelegate

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

- (void)runActionWithCallbackID:(NSString *)callbackID
                    withOptions:(NSDictionary *)options
       withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {
    NSArray *keys = [options allKeys];

    NSString *actionName = [keys firstObject];
    if (!actionName) {
        UA_LDEBUG(@"no action name was passed");
        completionHandler(nil);
        return;
    }

    NSString *decodedActionName = [actionName urlDecodedStringWithEncoding:NSUTF8StringEncoding];
    if (!decodedActionName) {
        UA_LDEBUG(@"unabled to decode action name");
        completionHandler(nil);
        return;
    }

    NSString *encodedArgumentsValue = [options valueForKey:actionName];
    id decodedArgumentsValue;
    if (encodedArgumentsValue) {
        decodedArgumentsValue = [self objectForEncodedArguments:encodedArgumentsValue];
    }

    //if we found an action by that name, and there's either no argument or a correctly decoded argument
    if (decodedArgumentsValue || !encodedArgumentsValue) {
        UAActionArguments *actionArgs = [UAActionArguments argumentsWithValue:decodedArgumentsValue
                                                                withSituation:UASituationRichPushAction];
        [UAActionRunner runActionWithName:decodedActionName withArguments:actionArgs withCompletionHandler:^(UAActionResult *result){
            if (result.error){
                UA_LDEBUG(@"action %@ completed with an error", decodedActionName);
                if (callbackID) {
                    //pass the error description back into JS wrapped in an Error object
                    NSString *script = [NSString stringWithFormat:@"UAirship.finishAction(new Error('%@'), null, '%@');",
                                        result.error.localizedDescription,
                                        callbackID];
                    completionHandler(script);
                } else {
                    completionHandler(nil);
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
        if (callbackID) {
            NSString *errorString = [NSString stringWithFormat:@"Error decoding arguments: %@", encodedArgumentsValue];
            NSString *script = [NSString stringWithFormat:@"UAirship.finishAction(new Error('%@'), null, '%@');", errorString, callbackID];
            completionHandler(script);
        } else {
            completionHandler(nil);
        }
    }
}

- (void)runBasicActionWithOptions:(NSDictionary *)options
         withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {

    for (NSString *actionName in options) {
        NSString *decodedActionName = [actionName urlDecodedStringWithEncoding:NSUTF8StringEncoding];
        if (!decodedActionName) {
            UA_LDEBUG(@"unable to decode action name");
            completionHandler(nil);
            return;
        }
        NSString *encodedArgumentsValue = [options objectForKey:actionName];
        NSString *decodedArgumentsValue = [encodedArgumentsValue urlDecodedStringWithEncoding:NSUTF8StringEncoding];

        UAActionArguments *actionArgs = [UAActionArguments argumentsWithValue:decodedArgumentsValue withSituation:UASituationRichPushAction];

        //if we found an action by that name, and there's either no argument or a correctly decoded argument
        if (!encodedArgumentsValue || decodedArgumentsValue) {
            [UAActionRunner runActionWithName:decodedActionName withArguments:actionArgs withCompletionHandler:^(UAActionResult *result){
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

- (void)callbackArguments:(NSArray *)args
              withOptions:(NSDictionary *)options
    withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {
    UA_LDEBUG(@"action js delegate arguments: %@ \n options: %@", args, options);

    //we need at least one argument
    //run-action is the full js/callback interface
    if ([[args firstObject] isEqualToString:@"run-action"]) {
        NSString *callbackID;
        //the callbackID is optional, if present we can make an async callback
        //into the JS environment, otherwise we'll just run the action to completion
        if (args.count > 1) {
            callbackID = [args objectAtIndex:1];
        }
        [self runActionWithCallbackID:callbackID
                          withOptions:options
                withCompletionHandler:completionHandler];
    } else if ([[args firstObject] isEqualToString:@"run-basic-action"]) {
        //run-basic-action is the 'demo-friendly' version with implicit string argument values and
        //allows multiple simultaneous actions
        [self runBasicActionWithOptions:options withCompletionHandler:completionHandler];
    } else {
        //arguments not recognized, pass a nil script result
        completionHandler(nil);
    }
}

@end
