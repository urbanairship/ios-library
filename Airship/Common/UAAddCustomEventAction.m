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
#import "UACustomEvent.h"
#import "UAirship.h"

NSString * const UAAddCustomEventActionErrorDomain = @"com.urbanairship.actions.addcustomeventaction";

@implementation UAAddCustomEventAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if ([arguments.value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = [NSDictionary dictionaryWithDictionary:arguments.value];
        NSString *eventName = [dict valueForKey:@"event_name"];
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
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    NSDictionary *dict = [NSDictionary dictionaryWithDictionary:arguments.value];

    UACustomEvent *event;
    id value = [dict valueForKey:@"event_value"];
    NSString *valueAsString;
    NSNumber *valueAsNumber;
    if ([value isKindOfClass:[NSString class]]) {
        valueAsString = [dict valueForKey:@"event_value"];
        event = [UACustomEvent eventWithName:[dict valueForKey:@"event_name"] valueFromString:valueAsString];
    } else if ([value isKindOfClass:[NSNumber class]]) {
        valueAsNumber = [dict valueForKey:@"event_value"];
        event = [UACustomEvent eventWithName:[dict valueForKey:@"event_name"] value:valueAsNumber];
    }

    event.transactionID = [dict valueForKey:@"transaction_id"];
    event.attributionType = [dict valueForKey:@"attribution_type"];
    event.attributionID = [dict valueForKey:@"attribution_id"];

    if ([event valid]) {
        completionHandler([UAActionResult emptyResult]);
    } else {
        NSError *error = [NSError errorWithDomain:UAAddCustomEventActionErrorDomain
                                             code:UAAddCustomEventActionErrorCodeInvalidEventName
                                         userInfo:@{NSLocalizedDescriptionKey:@"Invalid event. Verify event name is not empty and within 255 characters."}];

        completionHandler([UAActionResult resultWithError:error]);
    }
}

@end
