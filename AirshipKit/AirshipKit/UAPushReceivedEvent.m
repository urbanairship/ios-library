/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

#import "UAPushReceivedEvent+Internal.h"
#import "UAInboxUtils.h"
#import "UAEvent+Internal.h"
#import "UAAnalytics+Internal.h"

@implementation UAPushReceivedEvent

+ (instancetype)eventWithNotification:(NSDictionary *)notification {
    UAPushReceivedEvent *event = [[self alloc] init];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    NSString *richPushID = [UAInboxUtils inboxMessageIDFromNotification:notification];
    if (richPushID) {
        [data setValue:richPushID forKey:@"rich_push_id"];
    }

    // Add the std push ID, if present, else send "MISSING_SEND_ID"
    NSString *pushID = [notification objectForKey:@"_"];
    if (pushID) {
        [data setValue:pushID forKey:@"push_id"];
    } else {
        [data setValue:kUAMissingSendID forKey:@"push_id"];
    }

    // Add the metadata only if present
    NSString *metadata = [notification objectForKey:kUAPushMetadata];
    [data setValue:metadata forKey:@"metadata"];

    event.data = [data mutableCopy];
    return event;
}

- (NSString *)eventType {
    return @"push_received";
}

@end
