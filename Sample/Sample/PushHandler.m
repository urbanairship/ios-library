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

- (void)receivedForegroundNotification:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    UA_LDEBUG(@"Received a notification while the app was already in the foreground");

    // Only display an alert dialog if the push does not contain a rich push message id.
    // If it does, allow the InboxDelegate's richPushMessageAvailable: to handle it.
    if (![UAInboxUtils inboxMessageIDFromNotification:notification]) {

        id alertMessage = notification[@"aps"][@"alert"];
        if ([alertMessage isKindOfClass:[NSDictionary class]]) {
            alertMessage = alertMessage[@"body"];
        }

        if (alertMessage) {

            NSString *alertTitle = NSLocalizedStringFromTable(@"UA_Notification_Title", @"UAPushUI", @"System Push Settings Label");

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];

            [alertController addAction:cancelAction];

            UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

            alertController.popoverPresentationController.sourceView = topController.view;

            [topController presentViewController:alertController animated:YES completion:nil];
        }
        else {
            UALOG(@"Unable to parse message body");
        }
    }

    // Call the completion handler with the fetch results
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)launchedFromNotification:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    UA_LDEBUG(@"The application was launched or resumed from a notification");

    // Do something when launched via a notification

    // Call the completion handler with the fetch results
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)launchedFromNotification:(NSDictionary *)notification actionIdentifier:(NSString *)identifier completionHandler:(void (^)())completionHandler {
    UA_LDEBUG(@"The application was launched or resumed from a foreground user notification button");

    // Do something when launched via a user notification button

    // Call the completion handler
    completionHandler();
}

- (void) receivedBackgroundNotification:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    UA_LDEBUG(@"The application was started in the background from a user notification");

    // Call the completion handler
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)receivedBackgroundNotification:(NSDictionary *)notification actionIdentifier:(NSString *)identifier completionHandler:(void (^)())completionHandler {
    UA_LDEBUG(@"The application was started in the background from a user notification button");
    // Do any background tasks via a user notificaiton button

    // Call the completion handler
    completionHandler();
}



@end
