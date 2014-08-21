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

#import "UAInteractiveNotificationEvent.h"
#import "UAEvent+Internal.h"

#define kUAInteractiveNotificationEventSize 350
@implementation UAInteractiveNotificationEvent


+ (instancetype)eventWithNotificationAction:(UIUserNotificationAction *)action
                                 categoryId:(NSString *)category
                               notification:(NSDictionary *)notification {

    UAInteractiveNotificationEvent *event =  [[self alloc] init];

    BOOL foreground = action.activationMode == UIUserNotificationActivationModeForeground;

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data setValue:category forKey:@"button_group"];
    [data setValue:action.identifier forKey:@"button_id"];
    [data setValue:action.title forKey:@"button_description"];
    [data setValue:foreground ? @"true" : @"false" forKey:@"foreground"];
    [data setValue:notification[@"_"] forKey:@"send_id"];

    event.data = [NSDictionary dictionaryWithDictionary:data];

    return event;
}

- (NSString *)eventType {
    return @"interactive_notification_action";
}

- (NSUInteger)estimatedSize {
    return kUAInteractiveNotificationEventSize;
}

@end


