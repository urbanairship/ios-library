/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UANotificationResponse.h"
#import <UserNotifications/UserNotifications.h>

@interface UANotificationResponse()
@property (nonatomic, copy) NSString *actionIdentifier;
@property (nonatomic, copy) NSString *responseText;
@property (nonatomic, strong) UANotificationContent *notificationContent;
@property (nonatomic, strong) UNNotificationResponse *response;
@end

@implementation UANotificationResponse

// If the user opened the application from the notification.
NSString *const UANotificationDefaultActionIdentifier = @"com.apple.UNNotificationDefaultActionIdentifier";
// If the user dismissed the notification.
NSString *const UANotificationDismissActionIdentifier = @"com.apple.UNNotificationDismissActionIdentifier";

- (instancetype)initWithNotificationContent:(UANotificationContent *)notificationContent actionIdentifier:(NSString *)actionIdentifier responseText:(NSString *)responseText {
    self = [super init];

    if (self) {
        self.notificationContent = notificationContent;
        self.actionIdentifier = actionIdentifier;
        self.responseText = responseText;
    }

    return self;
}

- (instancetype)initWithNotificationResponse:(UNNotificationResponse *)response {
    self = [super init];

    if (self) {

        if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
            self.responseText = ((UNTextInputNotificationResponse *)response).userText;
        }

        self.notificationContent = [UANotificationContent notificationWithUNNotification:response.notification];
        self.actionIdentifier = response.actionIdentifier;
        self.response = response;
    }

    return self;
}

+ (instancetype)notificationResponseWithNotificationInfo:(NSDictionary *)notificationInfo
                                        actionIdentifier:(NSString *)actionIdentifier responseText:(NSString *)responseText {
    return [[UANotificationResponse alloc] initWithNotificationContent:[UANotificationContent notificationWithNotificationInfo:notificationInfo]
                                                      actionIdentifier:actionIdentifier
                                                          responseText:responseText];
}

+ (instancetype)notificationResponseWithUNNotificationResponse:(UNNotificationResponse *)response {
    return [[UANotificationResponse alloc] initWithNotificationResponse:response];
}


- (NSString *)description {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:self.responseText forKey:@"responseText"];
    [payload setValue:self.actionIdentifier forKey:@"actionIdentifier"];
    [payload setValue:self.notificationContent forKey:@"notificationContent"];
    return [payload description];
}

@end
