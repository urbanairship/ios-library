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

#if __has_include("AirshipKit/AirshipKit.h")
#import <AirshipKit/AirshipKit.h>
#else
#import "AirshipLib.h"
#endif

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

    completionHandler();
}

- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification {
    return UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound;
}

@end
