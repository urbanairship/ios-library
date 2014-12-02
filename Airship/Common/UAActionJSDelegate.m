/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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

#import "UAActionJSDelegate.h"
#import "UAGlobal.h"

#import "NSJSONSerialization+UAAdditions.h"
#import "NSString+UAURLEncoding.h"

#import "UAActionRunner.h"
#import "UAWebViewCallData.h"

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

- (NSDictionary *)createMetaDataFromCallData:(UAWebViewCallData *)data {
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    [metadata setValue:data.webView forKey:UAActionMetadataWebViewKey];
    [metadata setValue:data.message forKey:UAActionMetadataInboxMessageKey];
    return metadata;
}

/**
 * Handles the run-action-cb command.
 *
 * This supports async callbacks into JS functions, as well the passing of
 * arbitrary argument objects through JSON serialization of core types.  It is best
 * used from JavaScript, but can be used entirely through URL loading as well.
 *
 * @param callbackID A callback identifier generated in the JS layer. This can be nil.
 * @param data The call data passed in the JS delegate call.
 * @param completionHandler The completion handler passed in the JS delegate call.
 */
- (void)runActionWithCallbackID:(NSString *)callbackID
                           data:(UAWebViewCallData *)data
              completionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {


    NSArray *keys = [data.options allKeys];

    NSString *actionName = [keys firstObject];
    if (!actionName) {
        UA_LDEBUG(@"no action name was passed");
        completionHandler(nil);
        return;
    }

    NSString *decodedActionName = [actionName urlDecodedStringWithEncoding:NSUTF8StringEncoding];
    if (!decodedActionName) {
        UA_LDEBUG(@"unable to decode action name");
        completionHandler(nil);
        return;
    }

    id encodedArgumentsValue = [[data.options valueForKey:actionName] firstObject];
    id decodedArgumentsValue;
    if (encodedArgumentsValue && encodedArgumentsValue != [NSNull null]) {
        decodedArgumentsValue = [self objectForEncodedArguments:encodedArgumentsValue];

        if (!decodedArgumentsValue) {
            if (callbackID) {
                NSString *errorString = [NSString stringWithFormat:@"Error decoding arguments: %@", encodedArgumentsValue];
                NSString *script = [NSString stringWithFormat:@"UAirship.finishAction(new Error('%@'), null, '%@');", errorString, callbackID];
                completionHandler(script);
            } else {
                completionHandler(nil);
            }

            return;
        }
    }

    UAActionArguments *actionArgs = [UAActionArguments argumentsWithValue:decodedArgumentsValue
                                                            withSituation:UASituationWebViewInvocation
                                                              metadata:[self createMetaDataFromCallData:data]];
    
    [UAActionRunner runActionWithName:decodedActionName withArguments:actionArgs withCompletionHandler:^(UAActionResult *result) {
        UA_LDEBUG("Action %@ finished executing with status %ld", actionName, (long)result.status);
        if (!callbackID) {
            completionHandler(nil);
            return;
        }

        NSString *script = nil;
        switch (result.status) {
            case UAActionStatusCompleted:
            {
                NSString *resultString;
                if (result.value) {
                    NSError *error;
                    //if the action completed with a result value, serialize into JSON
                    //accepting fragments so we can write lower level JSON values
                    resultString = [NSJSONSerialization stringWithObject:result.value acceptingFragments:YES error:&error];
                    // If there was an error serializing, fall back to a string description.
                    if (error) {
                        UA_LDEBUG(@"Unable to serialize result value %@, falling back to string description", result.value);
                        resultString = [NSJSONSerialization stringWithObject:[result.value description] acceptingFragments:YES];
                    }
                }
                //in the case where there is no result value, pass null
                resultString = resultString ?: @"null";
                //note: JSON.parse('null') and JSON.parse(null) are functionally equivalent.
                script = [NSString stringWithFormat:@"UAirship.finishAction(null, '%@', '%@');", resultString, callbackID];
                break;
            }
            case UAActionStatusActionNotFound:
                script = [NSString stringWithFormat:@"UAirship.finishAction(new Error('%@'), null, '%@');",
                          [NSString stringWithFormat:@"No action found with name %@, skipping action.", actionName],
                          callbackID];
                break;
            case UAActionStatusError:
                script = [NSString stringWithFormat:@"UAirship.finishAction(new Error('%@'), null, '%@');",
                          result.error.localizedDescription,
                          callbackID];
                break;
            case UAActionStatusArgumentsRejected:
                script = [NSString stringWithFormat:@"UAirship.finishAction(new Error('%@'), null, '%@');",
                          [NSString stringWithFormat:@"Action %@ rejected arguments.", actionName],
                          callbackID];
                break;
        }

        completionHandler(script);
    }];
}

/**
 * Handles the run-actions command.
 *
 * This supports async callbacks into JS functions, as well the passing of
 * arbitrary argument objects through JSON serialization of core types.  It is best
 * used from JavaScript, but can be used entirely through URL loading as well.
 *
 * @param data The call data passed in the JS delegate call.
 * @param completionHandler The completion handler passed in the JS delegate call.
 */
- (void)runActionsWithData:(UAWebViewCallData *)data completionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {

    NSDictionary *decodedOptions = [self decodeActionArgumentsWithData:data basicEncoding:NO];

    for (NSString *decodedActionName in decodedOptions) {
        for (UAActionArguments *actionArguments in [decodedOptions objectForKey:decodedActionName]) {

            [UAActionRunner runActionWithName:decodedActionName
                                withArguments:actionArguments
                        withCompletionHandler:^(UAActionResult *result) {
                if (result.status == UAActionStatusCompleted) {
                    UA_LDEBUG(@"action %@ completed successfully", decodedActionName);
                } else {
                    UA_LDEBUG(@"action %@ completed with an error", decodedActionName);
                }
            }];
        }
    }

    completionHandler(nil);
}

/**
 * Handles the run-basic-actions callback.
 *
 * This does not support callbacks into the JS layer, and only allows
 * for passing string arguments to actions.  For convenience, multiple actions can
 * be passed in the query options, in which case they will all be run at once.
 *
 * @param data The call data passed in the JS delegate call.
 * @param completionHandler The completion handler passed in the JS delegate callback.
 */
- (void)runBasicActionsWithData:(UAWebViewCallData *)data
              completionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {

    NSDictionary *decodedOptions = [self decodeActionArgumentsWithData:data basicEncoding:YES];

    for (NSString *decodedActionName in decodedOptions) {
        for (UAActionArguments *actionArguments in [decodedOptions objectForKey:decodedActionName]) {

            [UAActionRunner runActionWithName:decodedActionName
                                withArguments:actionArguments
                        withCompletionHandler:^(UAActionResult *result) {
                            if (result.status == UAActionStatusCompleted) {
                                UA_LDEBUG(@"action %@ completed successfully", decodedActionName);
                            } else {
                                UA_LDEBUG(@"action %@ completed with an error", decodedActionName);
                            }
                        }];
        }
    }
    
    completionHandler(nil);
}

/**
 * Decodes options with basic URL or URL+json encoding
 *
 * @param data The UAWebViewCallData
 * @param basicEncoding Boolean to select for basic encoding
 * @return A dictionary of action arguments under action name keys or returns nil if decoding error occurs.
 */
- (NSDictionary *)decodeActionArgumentsWithData:(UAWebViewCallData *)data basicEncoding:(BOOL)basicEncoding {
    NSMutableDictionary *decodedOptions = [[NSMutableDictionary alloc] init];
    NSMutableArray *decodedActionArguments = [[NSMutableArray alloc] init];

    for (NSString *actionName in data.options) {
        NSString *decodedActionName = [actionName urlDecodedStringWithEncoding:NSUTF8StringEncoding];

        if (!decodedActionName || [decodedActionName isEqual:@""]) {
            UA_LDEBUG(@"Error decoding action name: %@", actionName);
            return nil;
        }

        for (id encodedArgumentsValue in [data.options objectForKey:actionName]) {

            id decodedArgumentsValue;

            if (encodedArgumentsValue && encodedArgumentsValue != [NSNull null] && basicEncoding) {
                decodedArgumentsValue = [encodedArgumentsValue urlDecodedStringWithEncoding:NSUTF8StringEncoding];
            }
            if (encodedArgumentsValue && encodedArgumentsValue != [NSNull null] && !basicEncoding) {
                decodedArgumentsValue =  [self objectForEncodedArguments:encodedArgumentsValue];
            }

            if (!decodedArgumentsValue && encodedArgumentsValue != [NSNull null]) {
                UA_LERR(@"Error decoding arguments: %@", encodedArgumentsValue);
                return nil;
            }
            // If encodedArgumentsValue successfully decodes, create actionArguments with the resulting decodedArgumentValue
            UAActionArguments *actionArgs = [UAActionArguments argumentsWithValue:decodedArgumentsValue
                                                                    withSituation:UASituationWebViewInvocation
                                                                         metadata:[self createMetaDataFromCallData:data]];
            [decodedActionArguments addObject:actionArgs];
        }

        [decodedOptions setObject: [[NSArray alloc] initWithArray:decodedActionArguments] forKey:decodedActionName];
        [decodedActionArguments removeAllObjects];
    }

    // if decoded options is unpopulated, then no actionNames are present in options, return nil
    if ([decodedOptions isEqual:@{}]) {
        UA_LERR(@"Error no options available to decode");
        return nil;
    }
    return decodedOptions;
}


- (void)callWithData:(UAWebViewCallData *)data
    withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler {
    UA_LDEBUG(@"action js delegate arguments: %@ \n options: %@", data.arguments, data.options);


    //we need at least one argument
    //run-action-cb is the full JS callback interface, and only runs one action at a time
    if ([data.name isEqualToString:@"run-action-cb"]) {
        //the callbackID is optional, if present we can make an async callback
        //into the JS environment, otherwise we'll just run the action to completion

        NSString *callbackID = [data.arguments firstObject];
        [self runActionWithCallbackID:callbackID data:data completionHandler:completionHandler];
    } else if ([data.name isEqualToString:@"run-actions"]) {
        //run-actions is the 'complex' version with JSON-encoded string arguments, and
        //allows multiple simultaneous actions
        [self runActionsWithData:data completionHandler:completionHandler];
    } else if ([data.name isEqualToString:@"run-basic-actions"]) {
        //run-basic-actions is the 'demo-friendly' version with implicit string argument values and
        //allows multiple simultaneous actions
        [self runBasicActionsWithData:data completionHandler:completionHandler];
    } else {
        //arguments not recognized, pass a nil script result
        completionHandler(nil);
    }
}

@end
