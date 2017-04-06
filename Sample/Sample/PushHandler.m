/* Copyright 2017 Urban Airship and Contributors */

#import "PushHandler.h"

@implementation PushHandler

-(void)receivedBackgroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // Application received a background notification
    UA_LDEBUG(@"The application received a background notification");

    // Call the completion handler
    completionHandler(UIBackgroundFetchResultNoData);
}

-(void)receivedForegroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)())completionHandler {
    // Application received a foreground notification
    UA_LDEBUG(@"The application received a foreground notification");

    // iOS 10 - let foreground presentations options handle it
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}]) {
        completionHandler();
        return;
    }

    // iOS 8 & 9 - show an alert dialog
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

    completionHandler();
}

-(void)receivedNotificationResponse:(UANotificationResponse *)notificationResponse completionHandler:(void (^)())completionHandler {
    UA_LDEBUG(@"The user selected the following action identifier:%@", notificationResponse.actionIdentifier);

    // display an alert with the notification content and any response text
    UANotificationContent *notificationContent = notificationResponse.notificationContent;
    NSString *alertTitle = notificationContent.alertTitle ? notificationContent.alertTitle : NSLocalizedStringFromTable(@"UA_Notification_Title", @"UAPushUI", @"Notification Alert");
    NSMutableString *message = [NSMutableString stringWithFormat:@"Action Identifier:\n%@",notificationResponse.actionIdentifier];
    NSString *alertBody = notificationContent.alertBody;
    if (alertBody.length) {
        [message appendString:[NSString stringWithFormat:@"\nAlert Body:\n%@",alertBody]];
    }
    NSString *categoryIdentifier = notificationContent.categoryIdentifier;
    if (categoryIdentifier.length) {
        [message appendString:[NSString stringWithFormat:@"\nCategory Identifier:\n%@",categoryIdentifier]];
    }
    NSString *responseText = notificationResponse.responseText;
    if (responseText != nil) {
        [message appendString:[NSString stringWithFormat:@"\nResponse:\n%@",responseText]];
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:alertTitle
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style: UIAlertActionStyleDefault handler:nil];
    [alertController addAction:defaultAction];
    
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    alertController.popoverPresentationController.sourceView = topController.view;
    [topController presentViewController:alertController animated:YES completion:nil];
    
    completionHandler();
}

- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification {
    return UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound;
}

@end
