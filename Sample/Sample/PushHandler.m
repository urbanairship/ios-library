/* Copyright 2017 Urban Airship and Contributors */

#import "PushHandler.h"

@implementation PushHandler

-(void)receivedBackgroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // Application received a background notification
    UA_LDEBUG(@"The application received a background notification");

    // Call the completion handler
    completionHandler(UIBackgroundFetchResultNoData);
}

-(void)receivedForegroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(void))completionHandler {
    // Application received a foreground notification
    UA_LDEBUG(@"The application received a foreground notification");

    // iOS 10 - let foreground presentations options handle it
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}]) {
        completionHandler();
        return;
    }

    // iOS 8 & 9 - show an alert dialog
    if (notificationContent.alertTitle || notificationContent.alertBody) {
        NSString *alertTitle = notificationContent.alertTitle ? notificationContent.alertTitle : NSLocalizedStringFromTable(@"UA_Notification_Title", @"UAPushUI", @"System Push Settings Label");
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:alertTitle
                                                                                 message:notificationContent.alertBody
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
            // If we have a message ID run the display inbox action to fetch and display the message.
            NSString *messageId = [UAInboxUtils inboxMessageIDFromNotification:notificationContent.notificationInfo];
            if (messageId) {
                [UAActionRunner runActionWithName:kUADisplayInboxActionDefaultRegistryName
                                            value:messageId
                                        situation:UASituationManualInvocation];
            }
        }];
        
        [alertController addAction:okAction];
        
        UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
        alertController.popoverPresentationController.sourceView = topController.view;
        [topController presentViewController:alertController animated:YES completion:nil];
    }
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
