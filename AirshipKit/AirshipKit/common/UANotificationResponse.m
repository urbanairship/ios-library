/* Copyright 2017 Urban Airship and Contributors */

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
