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

#import "UAInteractiveNotificationEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UANotificationAction.h"
#import "UAGlobal.h"

#define kUAInteractiveNotificationEventSize 350
@implementation UAInteractiveNotificationEvent

const NSUInteger UAInteractiveNotificationEventCharacterLimit = 255;

+ (instancetype)eventWithNotificationAction:(UANotificationAction *)action
                                 categoryID:(NSString *)category
                               notification:(NSDictionary *)notification {

    return [self eventWithNotificationAction:action categoryID:category notification:notification responseText:nil];
}

+ (instancetype)eventWithNotificationAction:(UANotificationAction *)action
                                 categoryID:(NSString *)category
                               notification:(NSDictionary *)notification
                               responseText:(nullable NSString *)responseText {

    UAInteractiveNotificationEvent *event = [[self alloc] init];

    BOOL foreground = (action.options & UNNotificationActionOptionForeground) > 0;

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data setValue:category forKey:@"button_group"];
    [data setValue:action.identifier forKey:@"button_id"];
    [data setValue:action.title forKey:@"button_description"];
    [data setValue:foreground ? @"true" : @"false" forKey:@"foreground"];
    [data setValue:notification[@"_"] forKey:@"send_id"];

    if (responseText) {
        NSString *userInputString = [responseText copy];
        if (userInputString.length > UAInteractiveNotificationEventCharacterLimit) {
            UA_LDEBUG(@"Interactive Notification %@ value exceeds %lu characters. Truncating to max chars", @"user_input", (unsigned long)
                    UAInteractiveNotificationEventCharacterLimit);
            userInputString = [userInputString substringToIndex:UAInteractiveNotificationEventCharacterLimit];
        }

        // Set the userInputString, which can be 0 - 255 characters. Empty string is acceptable.
        [data setValue:userInputString forKey:@"user_input"];
    }

    event.data = [NSDictionary dictionaryWithDictionary:data];

    return event;
}

- (NSString *)eventType {
    return @"interactive_notification_action";
}

- (UAEventPriority)priority {
    return UAEventPriorityHigh;
}

@end
