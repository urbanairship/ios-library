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

#import "UAEventPushReceived.h"
#import "UAInboxUtils.h"
#import "UAEvent+Internal.h"

@implementation UAEventPushReceived

+ (instancetype)eventWithNotification:(NSDictionary *)notification {
    UAEventPushReceived *event = [[self alloc] init];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    NSString *richPushId = [UAInboxUtils getRichPushMessageIDFromNotification:notification];
    if (richPushId) {
        [data setValue:richPushId forKey:@"rich_push_id"];
    }

    // Add the std push id, if present, else create a UUID
    NSString *pushId = [notification objectForKey:@"_"];
    if (pushId) {
        [data setValue:pushId forKey:@"push_id"];
    } else {
        [data setValue:[NSUUID UUID].UUIDString forKey:@"push_id"];
    }

    event.data = [data mutableCopy];
    return event;
}

- (NSString *)eventType {
    return @"push_received";
}

- (NSUInteger)estimatedSize {
    return kEventPushReceivedSize;
}

@end
