/* Copyright Airship and Contributors */

#import "UANativeBridgeActionHandler+Internal.h"
#import "UAGlobal.h"
#import "UAActionRunner.h"
#import "NSJSONSerialization+UAAdditions.h"

@implementation UANativeBridgeActionHandler

- (void)runActionsForCommand:(UAJavaScriptCommand *)command
                    metadata:(NSDictionary *)metadata
           completionHandler:(void (^)(NSString *))completionHandler {

    UA_LDEBUG(@"action js delegate name: %@ \n arguments: %@ \n options: %@", command.name, command.arguments, command.options);

    /*
     * run-action-cb performs a single action and calls the completion handler with
     * the result of the action. The action's value is JSON encoded.
     *
     * Expected format:
     * run-action-cb/<actionName>/<actionValue>/<callbackID>
     */

    if ([command.name isEqualToString:@"run-action-cb"]) {
        if (command.arguments.count != 3) {
            UA_LDEBUG(@"Unable to run-action-cb, wrong number of arguments. %@", command.arguments);
            completionHandler(nil);
            return;
        }

        NSString *actionName = command.arguments[0];
        id actionValue = [UANativeBridgeActionHandler parseArguments:command.arguments[1]];
        NSString *callbackID = command.arguments[2];

        // Run the action
        [self runAction:actionName
            actionValue:(actionValue == [NSNull null]) ? nil : actionValue
               metadata:metadata
             callbackID:callbackID
      completionHandler:completionHandler];
        return;
    }

    /*
     * run-actions performs several actions with the values JSON encoded.
     *
     * Expected format:
     * run-actions?<actionName>=<actionValue>&<anotherActionName>=<anotherActionValue>...
     */
    if ([command.name isEqualToString:@"run-actions"]) {
        [self runActionsWithValues:[self decodeActionValuesWithCommand:command basicEncoding:NO]
                          metadata:metadata];

        completionHandler(nil);
        return;
    }

    /*
     * run-basic-actions performs several actions with basic encoded action values.
     *
     * Expected format:
     * run-basic-actions?<actionName>=<actionValue>&<anotherActionName>=<anotherActionValue>...
     */
    if ([command.name isEqualToString:@"run-basic-actions"]) {
        [self runActionsWithValues:[self decodeActionValuesWithCommand:command basicEncoding:YES]
                          metadata:metadata];

        completionHandler(nil);
        return;
    }

    completionHandler(nil);
    return;
}

+ (id)parseArguments:(NSString *)arguments {
    //allow the reading of fragments so we can parse lower level JSON values
    id jsonDecodedArgs = [NSJSONSerialization objectWithString:arguments
                                                       options:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments];
    if (!jsonDecodedArgs) {
        UA_LDEBUG(@"unable to json decode action args: %@", arguments);
    } else {
        UA_LDEBUG(@"action arguments value: %@", jsonDecodedArgs);
    }
    return jsonDecodedArgs;
}

/**
 * Runs an action with a given value and performs a callback on completion.
 *
 * @param actionName The name of the action to perform
 * @param actionValue The action argument's value
 * @param metadata Optional metadata to pass to the action arguments.
 * @param callbackID A callback identifier generated in the JS layer. This can be `nil`.
 * @param completionHandler The completion handler passed in the JS delegate call.
 */
- (void)runAction:(NSString *)actionName
      actionValue:(id)actionValue
         metadata:(NSDictionary *)metadata
       callbackID:(NSString *)callbackID
completionHandler:(void (^)(NSString *))completionHandler {

    // JSONify the callback ID
    callbackID = [NSJSONSerialization stringWithObject:callbackID acceptingFragments:YES];

    UAActionCompletionHandler actionCompletionHandler = ^(UAActionResult *result) {
        UA_LDEBUG("Action %@ finished executing with status %ld", actionName, (long)result.status);
        if (!callbackID) {
            if (completionHandler) {
                completionHandler(nil);
            }
            return;
        }

        NSString *script;
        NSString *resultString;
        NSString *errorMessage;

        switch (result.status) {
            case UAActionStatusCompleted:
            {
                if (result.value) {
                    NSError *error;
                    //if the action completed with a result value, serialize into JSON
                    //accepting fragments so we can write lower level JSON values
                    resultString = [NSJSONSerialization stringWithObject:result.value acceptingFragments:YES error:&error];
                    // If there was an error serializing, fall back to a string description.
                    if (error) {
                        UA_LDEBUG(@"Unable to serialize result value %@, falling back to string description", result.value);
                        // JSONify the result string
                        resultString = [NSJSONSerialization stringWithObject:[result.value description] acceptingFragments:YES];
                    }
                }
                //in the case where there is no result value, pass null
                resultString = resultString ?: @"null";
                break;
            }
            case UAActionStatusActionNotFound:
                errorMessage = [NSString stringWithFormat:@"No action found with name %@, skipping action.", actionName];
                break;
            case UAActionStatusError:
                errorMessage = result.error.localizedDescription;
                break;
            case UAActionStatusArgumentsRejected:
                errorMessage = [NSString stringWithFormat:@"Action %@ rejected arguments.", actionName];
                break;
        }

        if (errorMessage) {
            // JSONify the error message
            errorMessage = [NSJSONSerialization stringWithObject:errorMessage acceptingFragments:YES];
            script = [NSString stringWithFormat:@"var error = new Error(); error.message = %@; UAirship.finishAction(error, null, %@);", errorMessage, callbackID];
        } else if (resultString) {
            script = [NSString stringWithFormat:@"UAirship.finishAction(null, %@, %@);", resultString, callbackID];
        }

        if (completionHandler) {
            completionHandler(script);
        }
    };

    [UAActionRunner runActionWithName:actionName
                                value:actionValue
                            situation:UASituationWebViewInvocation
                             metadata:metadata
                    completionHandler:actionCompletionHandler];
}

/**
 * Runs a dictionary of action names to an array of action values.
 *
 * @param actionValues A map of action name to an array of action values.
 * @param metadata Optional metadata to pass to the action arguments.
 */
- (void)runActionsWithValues:(NSDictionary *)actionValues metadata:(NSDictionary *)metadata {
    for (NSString *actionName in actionValues) {
        for (id actionValue in actionValues[actionName]) {
            [UAActionRunner runActionWithName:actionName
                                        value:(actionValue == [NSNull null]) ? nil : actionValue
                                    situation:UASituationWebViewInvocation
                                     metadata:metadata
                            completionHandler:^(UAActionResult *result) {
                                if (result.status == UAActionStatusCompleted) {
                                    UA_LDEBUG(@"action %@ completed successfully", actionName);
                                } else {
                                    UA_LDEBUG(@"action %@ completed with an error", actionName);
                                }
                            }];
        }
    }
}


/**
 * Decodes options with basic URL or URL+json encoding
 *
 * @param command The JavaScript command.
 * @param basicEncoding Boolean to select for basic encoding
 * @return A dictionary of action name to an array of action values.
 */
- (NSDictionary *)decodeActionValuesWithCommand:(UAJavaScriptCommand *)command basicEncoding:(BOOL)basicEncoding {
    if (!command.options.count) {
        UA_LERR(@"Error no options available to decode");
        return nil;
    }

    NSMutableDictionary *actionValues = [[NSMutableDictionary alloc] init];

    for (NSString *actionName in command.options) {
        NSMutableArray *values = [NSMutableArray array];

        for (id actionArg in command.options[actionName]) {
            if (!actionArg || actionArg == [NSNull null]) {
                [values addObject:[NSNull null]];
                continue;
            }

            id value;
            if (basicEncoding) {
                value = actionArg;
            } else {
                value = [UANativeBridgeActionHandler parseArguments:actionArg];
            }

            if (!value) {
                UA_LERR(@"Error decoding arguments: %@", actionArg);
                return nil;
            }

            [values addObject:value];
        }

        actionValues[actionName] = values;
    }

    return actionValues;
}

+ (BOOL)isActionCommand:(UAJavaScriptCommand *)command {
    NSString *name = command.name;
    return [name isEqualToString:@"run-actions"] ||
        [name isEqualToString:@"run-basic-actions"] ||
        [name isEqualToString:@"run-action-cb"];
}

@end
