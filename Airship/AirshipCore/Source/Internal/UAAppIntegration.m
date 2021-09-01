/* Copyright Airship and Contributors */

#import "UAAppIntegration.h"
#import "UAirship+Internal.h"
#import "UAActionArguments.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

#define kUNNotificationActionKey @"com.urbanairship.interactive_actions"

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

    [[UAirship analytics] addEvent:[[UADeviceRegistrationEvent alloc] init]];

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
            [self handleIncomingNotification:userInfo
                      foregroundPresentation:NO
                           completionHandler:completionHandler];

            break;

        case UIApplicationStateBackground:
        case UIApplicationStateInactive:
            // Background push
            [self handleIncomingNotification:userInfo
                      foregroundPresentation:NO
                           completionHandler:completionHandler];
            break;
    }

}

#pragma mark -
#pragma mark NSNotification methods

+ (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    UA_LDEBUG(@"Notification center will present notification: %@", notification);

    __block UNNotificationPresentationOptions options = [[UAirship push] presentationOptionsForNotification:notification];
    
    // Pushable components
    for (UAComponent *component in [UAirship shared].components) {
        if (![component conformsToProtocol:@protocol(UAPushableComponent)]) {
            continue;
        }

        UAComponent<UAPushableComponent> *pushable = (UAComponent<UAPushableComponent> *)component;
        if ([pushable respondsToSelector:@selector(presentationOptionsForNotification:defaultPresentationOptions:)]) {
            options = [pushable presentationOptionsForNotification:notification defaultPresentationOptions:options];
        }
    }

    if (![UAirship shared].config.isAutomaticSetupEnabled) {
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
    [self handleNotificationResponse:response completionHandler:completionHandler];
}
#endif

#pragma mark -
#pragma mark Notification handling

+ (void)handleForegroundNotification:(UNNotification *)notification mergedOptions:(UNNotificationPresentationOptions)options withCompletionHandler:(void(^)(void))completionHandler {
    BOOL foregroundPresentation = (options & UNNotificationPresentationOptionAlert) > 0;
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
#if !TARGET_OS_MACCATALYST
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        foregroundPresentation = (options & (UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner)) > 0;
    }
#endif
    #pragma clang diagnostic pop

    NSDictionary *userInfo = nil;
#if !TARGET_OS_TV
    userInfo = notification.request.content.userInfo;
#endif

    [self handleIncomingNotification:userInfo
              foregroundPresentation:foregroundPresentation
                   completionHandler:^(UIBackgroundFetchResult result) {
                       completionHandler();
                   }];
}

#if !TARGET_OS_TV
+ (void)handleNotificationResponse:(UNNotificationResponse *)response completionHandler:(void (^)(void))completionHandler {
    UA_LINFO(@"Received notification response: %@", response);

    dispatch_group_t dispatchGroup = dispatch_group_create();

    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSString *categoryIdentifier = response.notification.request.content.categoryIdentifier;

    NSString *responseText;
    if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
        responseText = ((UNTextInputNotificationResponse *)response).userText;
    }

    // Analytics
    if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        [[UAirship analytics] launchedFromNotification:response.notification.request.content.userInfo];
    } else {
        UNNotificationAction *notificationAction = [self notificationActionForCategory:categoryIdentifier
                                                                      actionIdentifier:response.actionIdentifier];
        if (notificationAction) {
            if (notificationAction.options & UNNotificationActionOptionForeground) {
                [[UAirship analytics] launchedFromNotification:userInfo];
            }
            id event = [[UAInteractiveNotificationEvent alloc] initWithAction:notificationAction
                                                                   category:categoryIdentifier
                                                                 notification:userInfo
                                                                 responseText:responseText];
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
#endif

+ (void)handleIncomingNotification:(NSDictionary *)userInfo
            foregroundPresentation:(BOOL)foregroundPresentation
                 completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    UA_LINFO(@"Received notification: %@", userInfo);

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
             [pushable receivedRemoteNotification:userInfo completionHandler:^(UIBackgroundFetchResult fetchResult) {
                 @synchronized (fetchResults) {
                     [fetchResults addObject:@(fetchResult)];
                 }
                 dispatch_group_leave(dispatchGroup);
             }];
         }
    }

    // Actions then push
    dispatch_group_enter(dispatchGroup);
    [self runActionsForRemoteNotification:userInfo foregroundPresentation:foregroundPresentation completionHandler:^(UIBackgroundFetchResult result) {
        @synchronized (fetchResults) {
            [fetchResults addObject:@(result)];
        }

        // UAPush
        [[UAirship push] handleRemoteNotification:userInfo foreground:foreground completionHandler:^(UIBackgroundFetchResult result) {
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

#if !TARGET_OS_TV
+ (void)runActionsForResponse:(UNNotificationResponse *)response completionHandler:(void (^)(void))completionHandler {
    // Payload
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSString *responseText;
    if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
        responseText = ((UNTextInputNotificationResponse *)response).userText;
    }

    NSDictionary *actionsPayload = [self actionsPayloadForNotification:userInfo
                                                      actionIdentifier:response.actionIdentifier];
    // Determine situation
    UASituation situation;
    if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        situation = UASituationLaunchedFromPush;
    } else {
        UNNotificationAction *notificationAction = [self notificationActionForCategory:response.notification.request.content.categoryIdentifier
                                                                      actionIdentifier:response.actionIdentifier];

        if (notificationAction.options & UNNotificationActionOptionForeground) {
            situation = UASituationForegroundInteractiveButton;
        } else {
            situation = UASituationBackgroundInteractiveButton;
        }
    }

    // Metadata
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    [metadata setValue:response.actionIdentifier forKey:UAActionMetadataUserNotificationActionIDKey];
    [metadata setValue:userInfo forKey:UAActionMetadataPushPayloadKey];
    [metadata setValue:responseText forKey:UAActionMetadataResponseInfoKey];

    // Run the actions
    [UAActionRunner runActionsWithActionValues:actionsPayload
                                     situation:situation
                                      metadata:metadata
                             completionHandler:^(UAActionResult *result) {
                                completionHandler();
                             }];
}
#endif

+ (void)runActionsForRemoteNotification:(NSDictionary *)userInfo
                 foregroundPresentation:(BOOL)foregroundPresentation
                      completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    UASituation situation = [UIApplication sharedApplication].applicationState == UIApplicationStateActive ? UASituationForegroundPush : UASituationBackgroundPush;
    NSDictionary *actionsPayload = userInfo;

    NSDictionary *metadata = @{ UAActionMetadataForegroundPresentationKey: @(foregroundPresentation),
                                UAActionMetadataPushPayloadKey: userInfo };

    // Run the actions
    [UAActionRunner runActionsWithActionValues:actionsPayload
                                     situation:situation
                                      metadata:metadata
                             completionHandler:^(UAActionResult *result) {
                                completionHandler((UIBackgroundFetchResult)[result fetchResult]);
                             }];

}

#if !TARGET_OS_TV
+ (NSDictionary *)actionsPayloadForNotification:(NSDictionary *)userInfo
                               actionIdentifier:(NSString *)actionIdentifier {
    if (!actionIdentifier || [actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        return userInfo;
    }

    return userInfo[kUNNotificationActionKey][actionIdentifier];
}

+ (UNNotificationAction *)notificationActionForCategory:(NSString *)category actionIdentifier:(NSString *)identifier {
    NSSet<UNNotificationCategory *> *categories = [UAirship push].combinedCategories;

    UNNotificationCategory *notificationCategory;
    UNNotificationAction *notificationAction;

    for (UNNotificationCategory *possibleCategory in categories) {
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

    for (UNNotificationAction *possibleAction in possibleActions) {
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
#endif

@end
