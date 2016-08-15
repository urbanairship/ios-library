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

#import "UAIncomingPushAction+Internal.h"
#import "UAPush.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UANotificationContent.h"
#import "UANotificationResponse.h"

@implementation UAIncomingPushAction

- (void)performWithArguments:(UAActionArguments *)arguments
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
        case UASituationForegroundInteractiveButton:
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
        case UASituationForegroundInteractiveButton:
        case UASituationBackgroundInteractiveButton:
            return [arguments.value isKindOfClass:[NSDictionary class]];
        default:
            return NO;
    }
}

- (void)handleForegroundPush:(NSDictionary *)notification
           completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAirship push].pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(receivedForegroundNotification:completionHandler:)]) {
        UANotificationContent *notificationContent = [UANotificationContent notificationWithNotificationInfo:notification];

        [pushDelegate receivedForegroundNotification:notificationContent completionHandler:^(UIBackgroundFetchResult result) {
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:(UAActionFetchResult)result]);
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)handleLaunchedFromPush:(NSDictionary *)notification
             completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAirship push].pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(receivedNotificationResponse:completionHandler:)]) {
        UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                           actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                            backgroundState:YES];

        [pushDelegate receivedNotificationResponse:response completionHandler:^{
            completionHandler([UAActionResult emptyResult]);
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)handleBackgroundPush:(NSDictionary *)notification
           completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAirship push].pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(receivedBackgroundNotification:completionHandler:)]) {
        completionHandler([UAActionResult emptyResult]);

        UANotificationContent *notificationContent = [UANotificationContent notificationWithNotificationInfo:notification];

        [pushDelegate receivedBackgroundNotification:notificationContent completionHandler:^(UIBackgroundFetchResult result) {
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:(UAActionFetchResult)result]);
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)handleBackgroundUserNotificationAction:(NSString *)identifier
                                  notification:(NSDictionary *)notification
                             completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAirship push].pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(receivedNotificationResponse:completionHandler:)]) {
        UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                           actionIdentifier:identifier
                                                                                            backgroundState:YES];

        [pushDelegate receivedNotificationResponse:response completionHandler:^(){
            completionHandler([UAActionResult emptyResult]);
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}


- (void)handleForegroundUserNotificationAction:(NSString *)identifier
                                  notification:(NSDictionary *)notification
                             completionHandler:(UAActionCompletionHandler)completionHandler {

    id<UAPushNotificationDelegate> pushDelegate = [UAirship push].pushNotificationDelegate;
    if ([pushDelegate respondsToSelector:@selector(receivedNotificationResponse:completionHandler:)]) {
        UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:notification
                                                                                           actionIdentifier:identifier
                                                                                            backgroundState:NO];

        [pushDelegate receivedNotificationResponse:response completionHandler:^(){
            completionHandler([UAActionResult emptyResult]);
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (BOOL)useFetchCompletionHandlerDelegates {
    id appDelegate = [UIApplication sharedApplication].delegate;
    return [UAirship shared].remoteNotificationBackgroundModeEnabled ||
    [appDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)];
}

@end
