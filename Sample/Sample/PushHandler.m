/* Copyright 2010-2019 Urban Airship and Contributors */

#import "PushHandler.h"

@implementation PushHandler

-(void)receivedBackgroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // Application received a background notification
    UA_LDEBUG(@"The application received a background notification");

    // Call the completion handler
    completionHandler(UIBackgroundFetchResultNoData);
}

-(void)receivedForegroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(void))completionHandler {
    UA_LDEBUG(@"The application received a foreground notification");
    completionHandler();
}

-(void)receivedNotificationResponse:(UANotificationResponse *)notificationResponse completionHandler:(void (^)(void))completionHandler {
    UANotificationContent *notificationContent = notificationResponse.notificationContent;

    NSLog(@"Received a notification response");
    NSLog(@"Alert Title:         %@",notificationContent.alertTitle);
    NSLog(@"Alert Body:          %@",notificationContent.alertBody);
    NSLog(@"Action Identifier:   %@",notificationResponse.actionIdentifier);
    NSLog(@"Category Identifier: %@",notificationContent.categoryIdentifier);
    NSLog(@"Response Text:       %@",notificationResponse.responseText);

    completionHandler();
}

- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification {
    return UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound;
}

@end
