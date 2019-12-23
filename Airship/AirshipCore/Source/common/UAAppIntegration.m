/* Copyright Airship and Contributors */

#import "UAAppIntegration.h"
#import "UAirship+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UAPush+Internal.h"
#import "UAPushableComponent.h"

#import "UADeviceRegistrationEvent+Internal.h"
#import "UAPushReceivedEvent+Internal.h"
#import "UAInteractiveNotificationEvent+Internal.h"
#import "UANotificationAction.h"
#import "UANotificationCategory.h"
#import "UAActionArguments.h"
#import "UAUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "UAActionRunner.h"
#import "UAActionRegistry+Internal.h"

#define kUANotificationActionKey @"com.urbanairship.interactive_actions"

@implementation UAAppIntegration

#pragma mark -
#pragma mark AppDelegate methods

+ (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    UA_LINFO(@"Application received backgound app refresh");

    [[UAirship push] updateAuthorizedNotificationTypes];
    completionHandler(UIBackgroundFetchResultNoData);
}

+ (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    UA_LINFO(@"Application registered device token: %@", [UAUtils deviceTokenStringFromDeviceToken:deviceToken]);

    [[UAirship analytics] addEvent:[UADeviceRegistrationEvent event]];

    [[UAirship push] application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

+ (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    UA_LERR(@"Application failed to register for remote notifications with error %@", error);
    
    [[UAirship push] application:application didFailToRegisterForRemoteNotificationsWithError:error];
}

+ (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    switch(application.applicationState) {
        UA_LTRACE(@"Received remote notification: %@", userInfo);
        case UIApplicationStateActive:
            if (![UAUtils isSilentPush:userInfo]) {
                // Handled by the userNotificationCenter:willPresentNotification:withCompletionHandler:
                completionHandler(UIBackgroundFetchResultNoData);
                break;
            }

            // Foreground push
            [self handleIncomingNotification:[UANotificationContent notificationWithNotificationInfo:userInfo]
                      foregroundPresentation:NO
                           completionHandler:completionHandler];

            break;

        case UIApplicationStateBackground:
        case UIApplicationStateInactive:
            // Background push
            [self handleIncomingNotification:[UANotificationContent notificationWithNotificationInfo:userInfo]
                      foregroundPresentation:NO
                           completionHandler:completionHandler];
            break;
    }

}

#pragma mark -
#pragma mark NSNotification methods

+ (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    UA_LDEBUG(@"Notification center will present notification: %@", notification);

    UNNotificationPresentationOptions options = [[UAirship push] presentationOptionsForNotification:notification];

    if (![UAirship shared].config.automaticSetupEnabled) {
        [self handleForegroundNotification:notification mergedOptions:options withCompletionHandler:^{
            completionHandler(options);
        }];
    } else {
        // UAAutoIntegration will call handleForegroundNotification:mergedOptions:withCompletionHandler:
        completionHandler(options);
    }
}

#if !TARGET_OS_TV   // UNNotificationResponse not available on tvOS
+ (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
    UA_LTRACE(@"Received notification response: %@", response);
    UANotificationResponse *airshipResponse = [UANotificationResponse notificationResponseWithUNNotificationResponse:response];
    [self handleNotificationResponse:airshipResponse completionHandler:completionHandler];
}
#endif

#pragma mark -
#pragma mark Notification handling

+ (void)handleForegroundNotification:(UNNotification *)notification mergedOptions:(UNNotificationPresentationOptions)options withCompletionHandler:(void(^)(void))completionHandler {
    BOOL foregroundPresentation = (options & UNNotificationPresentationOptionAlert) > 0;

    UANotificationContent *notificationContent = [UANotificationContent notificationWithUNNotification:notification];

    [self handleIncomingNotification:notificationContent
              foregroundPresentation:foregroundPresentation
                   completionHandler:^(UIBackgroundFetchResult result) {
                       completionHandler();
                   }];
}

+ (void)handleNotificationResponse:(UANotificationResponse *)response completionHandler:(void (^)(void))completionHandler {
    UA_LINFO(@"Received notification response: %@", response);

    dispatch_group_t dispatchGroup = dispatch_group_create();

    // Analytics
    if ([response.actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier]) {
        [[UAirship analytics] launchedFromNotification:response.notificationContent.notificationInfo];
    } else {
        UANotificationAction *notificationAction = [self notificationActionForCategory:response.notificationContent.categoryIdentifier
                                                                      actionIdentifier:response.actionIdentifier];
        if (notificationAction) {
            if (notificationAction.options & UANotificationActionOptionForeground) {
                [[UAirship analytics] launchedFromNotification:response.notificationContent.notificationInfo];
            }
            id event = [UAInteractiveNotificationEvent eventWithNotificationAction:notificationAction
                                                                        categoryID:response.notificationContent.categoryIdentifier
                                                                      notification:response.notificationContent.notificationInfo
                                                                      responseText:response.responseText];
            [[UAirship analytics] addEvent:event];
        }
    }

    // Pushable components
    for (UAComponent *component in [UAirship shared].components) {
        if (![component conformsToProtocol:@protocol(UAPushableComponent)]) {
            continue;
        }

        UAComponent<UAPushableComponent> *pushable = (UAComponent<UAPushableComponent> *)component;
        if ([pushable respondsToSelector:@selector(receivedNotificationResponse:completionHandler:)]) {
            dispatch_group_enter(dispatchGroup);
            [pushable receivedNotificationResponse:response completionHandler:^{
                dispatch_group_leave(dispatchGroup);
            }];
        }
    }

    // Actions then push
    dispatch_group_enter(dispatchGroup);
    [self runActionsForResponse:response completionHandler:^{
        // UAPush
        [[UAirship push] handleNotificationResponse:response completionHandler:^{
            dispatch_group_leave(dispatchGroup);
        }];
    }];

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), completionHandler);
}

+ (void)handleIncomingNotification:(UANotificationContent *)notificationContent
            foregroundPresentation:(BOOL)foregroundPresentation
                 completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    UA_LINFO(@"Received notification: %@", notificationContent);

    dispatch_group_t dispatchGroup = dispatch_group_create();
    __block NSMutableArray *fetchResults = [NSMutableArray array];
    BOOL foreground = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;

    // Pushable components
    for (UAComponent *component in [UAirship shared].components) {
        
        if (![component conformsToProtocol:@protocol(UAPushableComponent)]) {
             continue;
         }

         UAComponent<UAPushableComponent> *pushable = (UAComponent<UAPushableComponent> *)component;
         if ([pushable respondsToSelector:@selector(receivedRemoteNotification:completionHandler:)]) {
             dispatch_group_enter(dispatchGroup);
             [pushable receivedRemoteNotification:notificationContent completionHandler:^(UIBackgroundFetchResult fetchResult) {
                 @synchronized (fetchResults) {
                     [fetchResults addObject:@(fetchResult)];
                 }
                 dispatch_group_leave(dispatchGroup);
             }];
         }
    }

    // Actions then push
    dispatch_group_enter(dispatchGroup);
    [self runActionsForRemoteNotification:notificationContent foregroundPresentation:foregroundPresentation completionHandler:^(UIBackgroundFetchResult result) {
        @synchronized (fetchResults) {
            [fetchResults addObject:@(result)];
        }

        // UAPush
        [[UAirship push] handleRemoteNotification:notificationContent foreground:foreground completionHandler:^(UIBackgroundFetchResult result) {
            @synchronized (fetchResults) {
                [fetchResults addObject:@(result)];
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }];

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        // all processing of incoming notification is complete
        completionHandler([UAUtils mergeFetchResults:fetchResults]);
    });
}

#pragma mark -
#pragma mark Helpers

+ (void)runActionsForResponse:(UANotificationResponse *)response completionHandler:(void (^)(void))completionHandler {
    // Payload
    NSDictionary *actionsPayload = [self actionsPayloadForNotificationContent:response.notificationContent
                                                             actionIdentifier:response.actionIdentifier];
    // Determine situation
    UASituation situation;
    if ([response.actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier]) {
        situation = UASituationLaunchedFromPush;
    } else {
        UANotificationAction *notificationAction = [self notificationActionForCategory:response.notificationContent.categoryIdentifier
                                                                               actionIdentifier:response.actionIdentifier];

        if (notificationAction.options & UANotificationActionOptionForeground) {
            situation = UASituationForegroundInteractiveButton;
        } else {
            situation = UASituationBackgroundInteractiveButton;
        }
    }

    // Metadata
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    [metadata setValue:response.actionIdentifier forKey:UAActionMetadataUserNotificationActionIDKey];
    [metadata setValue:response.notificationContent.notificationInfo forKey:UAActionMetadataPushPayloadKey];
    [metadata setValue:response.responseText forKey:UAActionMetadataResponseInfoKey];

    // Run the actions
    [UAActionRunner runActionsWithActionValues:actionsPayload
                                     situation:situation
                                      metadata:metadata
                             completionHandler:^(UAActionResult *result) {
                                completionHandler();
                             }];
}

+ (void)runActionsForRemoteNotification:(UANotificationContent *)notificationContent
                 foregroundPresentation:(BOOL)foregroundPresentation
                      completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    UASituation situation = [UIApplication sharedApplication].applicationState == UIApplicationStateActive ? UASituationForegroundPush : UASituationBackgroundPush;
    NSDictionary *actionsPayload = [self actionsPayloadForNotificationContent:notificationContent actionIdentifier:nil];

    NSDictionary *metadata = @{ UAActionMetadataForegroundPresentationKey: @(foregroundPresentation),
                                UAActionMetadataPushPayloadKey: notificationContent.notificationInfo };

    // Run the actions
    [UAActionRunner runActionsWithActionValues:actionsPayload
                                     situation:situation
                                      metadata:metadata
                             completionHandler:^(UAActionResult *result) {
                                completionHandler((UIBackgroundFetchResult)[result fetchResult]);
                             }];

}

+ (NSDictionary *)actionsPayloadForNotificationContent:(UANotificationContent *)notificationContent
                                      actionIdentifier:(NSString *)actionIdentifier {
    if (!actionIdentifier || [actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier]) {
        return notificationContent.notificationInfo;
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

@end
