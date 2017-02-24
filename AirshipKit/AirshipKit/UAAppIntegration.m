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

#import "UAAppIntegration.h"
#import "UAirship.h"
#import "UAAnalytics+Internal.h"
#import "UAPush+Internal.h"
#import "UAInbox+Internal.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInAppMessaging+Internal.h"

#import "UADeviceRegistrationEvent+Internal.h"
#import "UAPushReceivedEvent+Internal.h"
#import "UAInteractiveNotificationEvent+Internal.h"

#import "UAActionArguments.h"
#import "UAUtils.h"
#import "UAConfig.h"
#import "UAActionRunner+Internal.h"
#import "UAActionRegistry+Internal.h"
#import "UAInboxUtils.h"
#import "UANotificationAction.h"
#import "UANotificationCategory.h"

#define kUANotificationActionKey @"com.urbanairship.interactive_actions"

@implementation UAAppIntegration

#pragma mark -
#pragma mark AppDelegate methods

+ (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // Convert device deviceToken to a hex string
    NSString *deviceTokenString = [self deviceTokenStringFromDeviceToken:deviceToken];
    UA_LINFO(@"Application registered device token: %@", deviceTokenString);

    [[UAirship shared].analytics addEvent:[UADeviceRegistrationEvent event]];

    [UAirship push].deviceToken = deviceTokenString;

    if (application.applicationState == UIApplicationStateBackground && [UAirship push].channelID) {
         UA_LDEBUG(@"Skipping device registration. The app is currently backgrounded.");
    } else {
        [[UAirship push] updateChannelRegistrationForcefully:NO];
    }
}

+ (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    [[UAirship push] updateAuthorizedNotificationTypes];
    [application registerForRemoteNotifications];
}

+ (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    switch(application.applicationState) {
        case UIApplicationStateActive:
            if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}] && ![UAUtils isSilentPush:userInfo]) {
                // Handled by the new userNotificationCenter:willPresentNotification:withCompletionHandler:
                completionHandler(UIBackgroundFetchResultNoData);
                break;
            }

            // Foreground push
            [self handleIncomingNotification:[UANotificationContent notificationWithNotificationInfo:userInfo]
                      foregroundPresentation:NO
                           completionHandler:completionHandler];

            break;

        case UIApplicationStateBackground:
            // Background push
            [self handleIncomingNotification:[UANotificationContent notificationWithNotificationInfo:userInfo]
                      foregroundPresentation:NO
                           completionHandler:completionHandler];
            break;

        case UIApplicationStateInactive:

            /*
             * iOS 10+ will only ever call application:receivedRemoteNotification:fetchCompletion as a result of content-available push
             */
            if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}] || [UAUtils isSilentPush:userInfo]) {
                [self handleIncomingNotification:[UANotificationContent notificationWithNotificationInfo:userInfo]
                          foregroundPresentation:NO
                               completionHandler:completionHandler];
            } else {
                UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:userInfo
                                                                                                   actionIdentifier:UANotificationDefaultActionIdentifier
                                                                                                       responseText:nil];

                [self handleNotificationResponse:response
                               completionHandler:^() {
                                   completionHandler(UIBackgroundFetchResultNoData);
                               }];
            }
    }

}

+ (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())handler {
    [self application:application handleActionWithIdentifier:identifier forRemoteNotification:userInfo withResponseInfo:nil completionHandler:handler];
}

+ (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void (^)())handler {
    NSString *responseText = responseInfo ? responseInfo[UIUserNotificationActionResponseTypedTextKey] : nil;
    UANotificationResponse *response = [UANotificationResponse notificationResponseWithNotificationInfo:userInfo
                                                                                       actionIdentifier:identifier
                                                                                        responseText:responseText];
   [self handleNotificationResponse:response completionHandler:^(UIBackgroundFetchResult result) {
       handler();
   }];
}


#pragma mark -
#pragma mark NSNotification methods

+ (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    UA_LDEBUG(@"Notification center will present notification: %@", notification);

    UNNotificationPresentationOptions options = [[UAirship push] presentationOptionsForNotification:notification];
    completionHandler(options);

    if (![UAirship shared].config.automaticSetupEnabled) {
        [self handleForegroundNotification:notification mergedOptions:options withCompletionHandler:^{
            completionHandler(options);
        }];
    } else {
        // UAAutoIntegration will call handleForegroundNotification:mergedOptions:withCompletionHandler:
        completionHandler(options);
    }
}

+ (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler {
    UANotificationResponse *airshipResponse = [UANotificationResponse notificationResponseWithUNNotificationResponse:response];

    [self handleNotificationResponse:airshipResponse completionHandler:^(UIBackgroundFetchResult result) {
        completionHandler();
    }];
}

#pragma mark -
#pragma mark Notification handling

+ (void)handleForegroundNotification:(UNNotification *)notification mergedOptions:(UNNotificationPresentationOptions)options withCompletionHandler:(void(^)())completionHandler {
    BOOL foregroundPresentation = (options & UNNotificationPresentationOptionAlert) > 0;

    UANotificationContent *notificationContent = [UANotificationContent notificationWithUNNotification:notification];

    [self handleIncomingNotification:notificationContent
              foregroundPresentation:foregroundPresentation
                   completionHandler:^(UIBackgroundFetchResult result) {
                       completionHandler();
                   }];
}

+ (void)handleNotificationResponse:(UANotificationResponse *)response
                 completionHandler:(void (^)())completionHandler {

    UA_LINFO(@"Received notification response: %@", response);

    // Clear any in-app messages
    [[UAirship inAppMessaging] handleNotificationResponse:response];

    UASituation situation;
    NSDictionary *actionsPayload = [self actionsPayloadForNotificationContent:response.notificationContent actionIdentifier:response.actionIdentifier];

    if ([response.actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier]) {
        [[UAirship shared].analytics launchedFromNotification:response.notificationContent.notificationInfo];
        situation = UASituationLaunchedFromPush;
    } else {
        UANotificationAction *notificationAction = [self notificationActionForCategory:response.notificationContent.categoryIdentifier
                                                                      actionIdentifier:response.actionIdentifier];


        if (!notificationAction) {
            [[UAirship push] handleNotificationResponse:response completionHandler:completionHandler];
            return;
        }

        if (notificationAction.options & UNNotificationActionOptionForeground) {
            [[UAirship shared].analytics launchedFromNotification:response.notificationContent.notificationInfo];
            situation = UASituationForegroundInteractiveButton;
        } else {
            situation = UASituationBackgroundInteractiveButton;
        }

        id event = [UAInteractiveNotificationEvent eventWithNotificationAction:notificationAction
                                                                    categoryID:response.notificationContent.categoryIdentifier
                                                                  notification:response.notificationContent.notificationInfo
                                                                  responseText:response.responseText];

        [[UAirship shared].analytics addEvent:event];
    }

    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    [metadata setValue:response.actionIdentifier forKey:UAActionMetadataUserNotificationActionIDKey];
    [metadata setValue:response.notificationContent.notificationInfo forKey:UAActionMetadataPushPayloadKey];
    [metadata setValue:response.responseText forKey:UAActionMetadataResponseInfoKey];

    // Run the actions
    [UAActionRunner runActionsWithActionValues:actionsPayload
                                     situation:situation
                                      metadata:metadata
                             completionHandler:^(UAActionResult *result) {
                                 [[UAirship push] handleNotificationResponse:response completionHandler:completionHandler];
                             }];
}

+ (void)handleIncomingNotification:(UANotificationContent *)notificationContent
            foregroundPresentation:(BOOL)foregroundPresentation
                 completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    UA_LINFO(@"Received notification: %@", notificationContent);

    // Process any in-app messages
    [[UAirship inAppMessaging] handleRemoteNotification:notificationContent];

    UASituation situation = [UIApplication sharedApplication].applicationState == UIApplicationStateActive ? UASituationForegroundPush : UASituationBackgroundPush;
    NSDictionary *actionsPayload = [self actionsPayloadForNotificationContent:notificationContent actionIdentifier:nil];

    NSDictionary *metadata = @{ UAActionMetadataForegroundPresentationKey: @(foregroundPresentation),
                                UAActionMetadataPushPayloadKey: notificationContent.notificationInfo };

    __block NSUInteger resultCount = 0;
    __block NSUInteger expectedCount = 1;
    __block NSMutableArray *fetchResults = [NSMutableArray array];

    // Refresh the message center, call completion block when finished
    if ([UAInboxUtils inboxMessageIDFromNotification:notificationContent.notificationInfo]) {
        expectedCount = 2;

        [[UAirship inbox].messageList retrieveMessageListWithSuccessBlock:^{
            [fetchResults addObject:[NSNumber numberWithInt:UIBackgroundFetchResultNewData]];

            dispatch_async(dispatch_get_main_queue(), ^{
                resultCount++;

                if (expectedCount == resultCount) {
                    completionHandler([UAUtils mergeFetchResults:fetchResults]);
                }
            });
        } withFailureBlock:^{
            [fetchResults addObject:[NSNumber numberWithInt:UIBackgroundFetchResultFailed]];

            dispatch_async(dispatch_get_main_queue(), ^{
                resultCount++;

                if (expectedCount == resultCount) {
                    completionHandler([UAUtils mergeFetchResults:fetchResults]);
                }
            });
        }];
    }

    // Run the actions
    [UAActionRunner runActionsWithActionValues:actionsPayload
                                     situation:situation
                                      metadata:metadata
                             completionHandler:^(UAActionResult *result) {
                                 [fetchResults addObject:[NSNumber numberWithInt:(UIBackgroundFetchResult)[result fetchResult]]];

                                 [[UAirship push] handleRemoteNotification:notificationContent
                                                                foreground:(situation == UASituationForegroundPush)
                                                         completionHandler:^(UIBackgroundFetchResult fetchResult) {
                                                             [fetchResults addObject:[NSNumber numberWithInt:fetchResult]];

                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                 resultCount++;

                                                                 if (expectedCount == resultCount) {
                                                                     completionHandler([UAUtils mergeFetchResults:fetchResults]);
                                                                 }
                                                             });
                                                         }];

                             }];
}

#pragma mark -
#pragma mark Helpers

+ (NSDictionary *)actionsPayloadForNotificationContent:(UANotificationContent *)notificationContent actionIdentifier:(NSString *)actionIdentifier {
    if (!actionIdentifier || [actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier]) {
        NSMutableDictionary *mutableActionsPayload = [NSMutableDictionary dictionaryWithDictionary:notificationContent.notificationInfo];

        NSString *messageID = [UAInboxUtils inboxMessageIDFromNotification:notificationContent.notificationInfo];
        if (messageID) {
            NSSet *inboxActionNames = [NSSet setWithArray:@[kUADisplayInboxActionDefaultRegistryAlias,
                                                            kUADisplayInboxActionDefaultRegistryName,
                                                            kUAOverlayInboxMessageActionDefaultRegistryAlias,
                                                            kUAOverlayInboxMessageActionDefaultRegistryName]];

            NSSet *actionNames = [NSSet setWithArray:[mutableActionsPayload allKeys]];

            if (![actionNames intersectsSet:inboxActionNames]) {
                mutableActionsPayload[kUADisplayInboxActionDefaultRegistryAlias] = messageID;
            }
        }

        return [mutableActionsPayload copy];
    }

    return notificationContent.notificationInfo[kUANotificationActionKey][actionIdentifier];
}

+ (UANotificationAction *)notificationActionForCategory:(NSString *)category actionIdentifier:(NSString *)identifier {
    NSSet *categories = [UAirship push].combinedCategories;

    UANotificationCategory *notificationCategory;
    UANotificationAction *notificationAction;

    for (UANotificationCategory *possibleCategory in categories) {
        if ([possibleCategory.identifier isEqualToString:category]) {
            notificationCategory = possibleCategory;
            break;
        }
    }

    if (!notificationCategory) {
        UA_LERR(@"Unknown notification category identifier %@", category);
        return nil;
    }

    NSMutableArray *possibleActions = [NSMutableArray arrayWithArray:notificationCategory.actions];

    for (UANotificationAction *possibleAction in possibleActions) {
        if ([possibleAction.identifier isEqualToString:identifier]) {
            notificationAction = possibleAction;
            break;
        }
    }

    if (!notificationAction) {
        UA_LERR(@"Unknown notification action identifier %@", identifier);
        return nil;
    }

    return notificationAction;
}

+ (NSString *)deviceTokenStringFromDeviceToken:(NSData *)deviceToken {
    NSMutableString *deviceTokenString = [NSMutableString stringWithCapacity:([deviceToken length] * 2)];
    const unsigned char *bytes = (const unsigned char *)[deviceToken bytes];

    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [deviceTokenString appendFormat:@"%02X", bytes[i]];
    }

    return [deviceTokenString lowercaseString];
}

@end
