/* Copyright Airship and Contributors */

#import "PushHandler.h"

@import UserNotifications;
@import UIKit;

@implementation PushHandler

-(void)receivedBackgroundNotification:(UNNotificationContent *)notificationContent completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // Application received a background notification
    NSLog(@"The application received a background notification");

    // Call the completion handler
    completionHandler(UIBackgroundFetchResultNoData);
}

-(void)receivedForegroundNotification:(UNNotificationContent *)notificationContent completionHandler:(void (^)(void))completionHandler {
    NSLog(@"The application received a foreground notification");
    completionHandler();
}

-(void)receivedNotificationResponse:(UNNotificationResponse *)notificationResponse completionHandler:(void (^)(void))completionHandler {
    UNNotificationContent *notificationContent = notificationResponse.notification.request.content;
    NSString *userText = @"";
    if ([notificationResponse isKindOfClass:[UNTextInputNotificationResponse class]]) {
        userText = ((UNTextInputNotificationResponse *)notificationResponse).userText;
    }

    NSLog(@"Received a notification response");
    NSLog(@"Alert Title:         %@",notificationContent.title);
    NSLog(@"Alert Body:          %@",notificationContent.body);
    NSLog(@"Action Identifier:   %@",notificationResponse.actionIdentifier);
    NSLog(@"Category Identifier: %@",notificationContent.categoryIdentifier);
    NSLog(@"Response Text:       %@",userText);

    completionHandler();
}

- (UNNotificationPresentationOptions)extendPresentationOptions:(UNNotificationPresentationOptions)options notification:(UNNotification *)notification {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#if !TARGET_OS_MACCATALYST
    if (@available(iOS 14.0, *)) {
        return options | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner;
    } else {
        return options | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionAlert;
    }
#else
    return options | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionAlert;
#endif
#pragma clang diagnostic pop
}

@end
