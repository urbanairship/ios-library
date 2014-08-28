/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

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

#import "UAAddCustomEventAction.h"
#import "UACustomEvent+Internal.h"
#import "UAirship.h"
#import "UAAnalytics.h"

NSString * const UAAddCustomEventActionErrorDomain = @"UAAddCustomEventActionError";

@implementation UAAddCustomEventAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if ([arguments.value isKindOfClass:[NSDictionary class]]) {
        NSString *eventName = [arguments.value valueForKey:@"event_name"];
        if (eventName) {
            return YES;
        } else {
            UA_LDEBUG(@"UAAddCustomEventAction requires an event name in the event data.");
            return NO;
        }
    } else {
        UA_LDEBUG(@"UAAddCustomEventAction requires a dictionary of event data.");
        return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
                  actionName:(NSString *)name
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSDictionary *dict = [NSDictionary dictionaryWithDictionary:arguments.value];

    NSString *eventName = [self parseStringFromDictionary:dict key:@"event_name"];
    NSString *eventValue = [self parseStringFromDictionary:dict key:@"event_value"];
    NSString *interactionID = [self parseStringFromDictionary:dict key:@"interaction_id"];
    NSString *interactionType = [self parseStringFromDictionary:dict key:@"interaction_type"];
    NSString *transactionID = [self parseStringFromDictionary:dict key:@"transaction_id"];

    UACustomEvent *event = [UACustomEvent eventWithName:eventName valueFromString:eventValue];
    event.transactionID = transactionID;

    if (interactionID || interactionType) {
        event.interactionType = interactionType;
        event.interactionID = interactionID;
    } else {
        id message = [arguments.metadata objectForKey:UAActionMetadataInboxMessageKey];
        if (message) {
            [event setInteractionFromMessage:message];
        }
    }

    // Set the conversion send id if the action was triggered from a push
    event.conversionSendId = arguments.metadata[UAActionMetadataPushPayloadKey][@"_"];

    if ([event isValid]) {
        [[UAirship shared].analytics addEvent:event];
        completionHandler([UAActionResult emptyResult]);
    } else {
        NSError *error = [NSError errorWithDomain:UAAddCustomEventActionErrorDomain
                                             code:UAAddCustomEventActionErrorCodeInvalidEventName
                                         userInfo:@{NSLocalizedDescriptionKey:@"Invalid event. Verify event name is not empty and within 255 characters."}];

        completionHandler([UAActionResult resultWithError:error]);
    }
}

/**
 * Helper method to parse a string from a dictionary's value.
 * @param dict The dictionary to be parsed.
 * @param key The specified key.
 * @return The string parsed from the dicitionary.
 */
- (NSString *)parseStringFromDictionary:(NSDictionary *)dict key:(NSString *)key {
    id value = [dict objectForKey:key];
    if (!value) {
        return nil;
    } else if ([value isKindOfClass:[NSString class]]) {
        return value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    } else {
        return [value description];
    }
}

@end
