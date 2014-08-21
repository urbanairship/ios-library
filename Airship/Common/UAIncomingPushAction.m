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

#import "UAIncomingPushAction.h"
#import "UAPush.h"
#import "UAirship.h"

@implementation UAIncomingPushAction

- (void)performWithArguments:(UAActionArguments *)arguments
                  actionName:(NSString *)actionName
           completionHandler:(UAActionCompletionHandler)completionHandler {
    switch (arguments.situation) {
        case UASituationForegroundPush:
            [self handleForegroundPush:arguments.value completionHandler:completionHandler];
            break;
        case UASituationLaunchedFromPush:
            [self handleLaunchedFromPush:arguments.value completionHandler:completionHandler];
            break;
        case UASituationBackgroundPush:
            [self handleBackgroundPush:arguments.value completionHandler:completionHandler];
            break;
        case UASituationBackgroundInteractiveButton:
            [self handleBackgroundUserNotificationAction:arguments.metadata[UAActionMetadataUserNotificationActionIDKey]
                                            notification:arguments.value
                                       completionHandler:completionHandler];
            break;
        case UASituationForegoundInteractiveButton:
            [self handleForegroundUserNotificationAction:arguments.metadata[UAActionMetadataUserNotificationActionIDKey]
                                            notification:arguments.value
                                       completionHandler:completionHandler];
            break;
        default:
            completionHandler([UAActionResult emptyResult]);
            break;
    }
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    switch (arguments.situation) {
        case UASituationBackgroundPush:
        case UASituationLaunchedFromPush:
        case UASituationForegroundPush:
        case UASituationForegoundInteractiveButton:
        case UASituationBackgroundInteractiveButton:
            return [arguments.value isKindOfClass:[NSDictionary class]];
        default:
            return NO;
    }
}

- (void)handleForegroundPush:(NSDictionary *)notification
          completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAPush shared].pushNotificationDelegate;

    // Please refer to the following Apple documentation for full details on handling the userInfo payloads
    // http://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/ApplePushService/ApplePushService.html#//apple_ref/doc/uid/TP40008194-CH100-SW1
    NSDictionary *apsDict = [notification objectForKey:@"aps"];
    if (apsDict) {
        // Alert
        id alert = [apsDict valueForKey:@"alert"];
        if (alert) {
            if ([alert isKindOfClass:[NSString class]] &&
                [pushDelegate respondsToSelector:@selector(displayNotificationAlert:)]) {

                // The alert is a single string message so we can display it
                [pushDelegate displayNotificationAlert:alert];
            } else if ([pushDelegate respondsToSelector:@selector(displayLocalizedNotificationAlert:)]) {
                // The alert is a a dictionary with more localization details
                // This should be customized to fit your message details or usage scenario
                [pushDelegate displayLocalizedNotificationAlert:alert];
            }
        }

        // Badge
        NSString *badgeNumber = [apsDict valueForKey:@"badge"];
        if (badgeNumber && ![UAPush shared].autobadgeEnabled && [pushDelegate respondsToSelector:@selector(handleBadgeUpdate:)]) {
            [pushDelegate handleBadgeUpdate:[badgeNumber intValue]];
        }

        // Sound
        NSString *soundName = [apsDict valueForKey:@"sound"];
        if (soundName && [pushDelegate respondsToSelector:@selector(playNotificationSound:)]) {
            [pushDelegate playNotificationSound:[apsDict objectForKey:@"sound"]];
        }
    }


    if (self.useFetchCompletionHandlerDelegates) {
        if ([pushDelegate respondsToSelector:@selector(receivedForegroundNotification:fetchCompletionHandler:)]) {
            [pushDelegate receivedForegroundNotification:notification fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                completionHandler([UAActionResult resultWithValue:nil withFetchResult:(UAActionFetchResult)result]);
            }];
        } else {
            if ([pushDelegate respondsToSelector:@selector(receivedForegroundNotification:)]) {

                UA_LWARN(@"Application is configured with background remote notifications."
                         "PushNotificationDelegate should implement receivedForegroundNotification:fetchCompletionHandler: instead of receivedForegroundNotification:."
                         "receivedForegroundNotification: will still be called.");

                [pushDelegate receivedForegroundNotification:notification];
            }

            completionHandler([UAActionResult emptyResult]);
        }
    } else {
        if ([pushDelegate respondsToSelector:@selector(receivedForegroundNotification:)]) {
            [pushDelegate receivedForegroundNotification:notification];
        }

        completionHandler([UAActionResult emptyResult]);
    }

}

- (void)handleLaunchedFromPush:(NSDictionary *)notification
          completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAPush shared].pushNotificationDelegate;

    if (self.useFetchCompletionHandlerDelegates) {
        if ([pushDelegate respondsToSelector:@selector(launchedFromNotification:fetchCompletionHandler:)]) {
            [pushDelegate launchedFromNotification:notification fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                completionHandler([UAActionResult resultWithValue:nil withFetchResult:(UAActionFetchResult)result]);
            }];
        } else {
            if ([pushDelegate respondsToSelector:@selector(launchedFromNotification:)]) {

                UA_LWARN(@"Application is configured with background remote notifications."
                         "PushNotificationDelegate should implement launchedFromNotification:fetchCompletionHandler: instead of launchedFromNotification:."
                         "launchedFromNotification: will still be called.");

                [pushDelegate launchedFromNotification:notification];
            }

            completionHandler([UAActionResult emptyResult]);
        }
    } else {
        if ([pushDelegate respondsToSelector:@selector(launchedFromNotification:)]) {
            [pushDelegate launchedFromNotification:notification];
        }

        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)handleBackgroundPush:(NSDictionary *)notification
          completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAPush shared].pushNotificationDelegate;

    if (self.useFetchCompletionHandlerDelegates) {
        if ([pushDelegate respondsToSelector:@selector(receivedBackgroundNotification:fetchCompletionHandler:)]) {
            [pushDelegate receivedBackgroundNotification:notification fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                completionHandler([UAActionResult resultWithValue:nil withFetchResult:(UAActionFetchResult)result]);
            }];
        } else {
            if ([pushDelegate respondsToSelector:@selector(receivedBackgroundNotification:)]) {

                UA_LWARN(@"Application is configured with background remote notifications."
                         "PushNotificationDelegate should implement receivedBackgroundNotification:fetchCompletionHandler: instead of receivedBackgroundNotification:."
                         "receivedBackgroundNotification: will still be called.");

                [pushDelegate receivedBackgroundNotification:notification];
            }

            completionHandler([UAActionResult emptyResult]);
        }
    } else {
        if ([pushDelegate respondsToSelector:@selector(receivedBackgroundNotification:)]) {
            [pushDelegate receivedBackgroundNotification:notification];
        }

        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)handleBackgroundUserNotificationAction:(NSString *)identifier
                                  notification:(NSDictionary *)notification
                             completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAPush shared].pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(receivedBackgroundNotification:actionIdentifier:completionHandler:)]) {
        [pushDelegate receivedBackgroundNotification:notification actionIdentifier:identifier completionHandler:^{
            completionHandler([UAActionResult emptyResult]);
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}


- (void)handleForegroundUserNotificationAction:(NSString *)identifier
                                  notification:(NSDictionary *)notification
                             completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAPush shared].pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(launchedFromNotification:actionIdentifier:completionHandler:)]) {
        [pushDelegate launchedFromNotification:notification actionIdentifier:identifier completionHandler:^{
            completionHandler([UAActionResult emptyResult]);
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (BOOL)useFetchCompletionHandlerDelegates {
    id appDelegate = [UIApplication sharedApplication].delegate;
    return [UAirship shared].remoteNotificationBackgroundModeEnabled
        || [appDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)];

}

@end
