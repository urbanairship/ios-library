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

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Application hooks required by Urban Airship. If `automaticSetupEnabled` is enabled
 * (enabled by default), Urban Airship will automatically integrate these calls into
 * the application by swizzling methods. If `automaticSetupEnabled` is disabled,
 * the application must call through to every method provided by this class.
 */
@interface UAAppIntegration : NSObject


///---------------------------------------------------------------------------------------
/// @name UNUserNotificationDelegate hooks
///---------------------------------------------------------------------------------------

/**
 * Must be called by the UNUserNotificationDelegate's
 * userNotificationCenter:willPresentNotification:withCompletionHandler.
 *
 * Note: This method is relevant only for iOS 10 and above.
 *
 * @param center The notification center.
 * @param response The notification response.
 * @param completionHandler A completion handler.
 */
+ (void)userNotificationCenter:(UNUserNotificationCenter *)center
   didReceiveNotificationResponse:(UNNotificationResponse *)response
            withCompletionHandler:(void(^)())completionHandler;

/**
 * Must be called by the UNUserNotificationDelegate's
 * userNotificationCenter:willPresentNotification:withCompletionHandler.
 *
 * Note: this method is relevant only for iOS 10 and above.
 *
 * @param center The notification center.
 * @param notification The notification about to be presented.
 * @param completionHandler A completion handler to be called with the desired notification presentation options.
 */
+ (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler;


///---------------------------------------------------------------------------------------
/// @name UIApplicationDelegate hooks
///---------------------------------------------------------------------------------------

/**
 * Must be called by the UIApplicationDelegate's
 * application:didRegisterForRemoteNotificationsWithDeviceToken:.
 *
 * @param application The application instance.
 * @param deviceToken The APNS device token.
 */
+ (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

/**
 * Must be called by the UIApplicationDelegate's
 * application:didReceiveRemoteNotification:fetchCompletionHandler:.
 *
 * @param application The application instance.
 * @param userInfo The remote notification.
 * @param completionHandler The completion handler.
 */
+ (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

/**
 * Must be called by the UIApplicationDelegate's
 * application:didRegisterUserNotificationSettings:.
 *
 * Note: This method is relevant only for apps targeting iOS 8 and iOS 9.
 *
 * @param application The application instance.
 * @param notificationSettings The user notification settings.
 */
+ (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;

/**
 * Must be called by the UIApplicationDelegate's
 * application:handleActionWithIdentifier:forRemoteNotification:completionHandler
 *
 * Note: This method is relevant only for apps targeting iOS 8 and iOS 9.
 *
 * @param application The application instance.
 * @param identifier The action identifier.
 * @param userInfo The remote notification.
 * @param handler The completion handler
 */
+ (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())handler;

/**
 * Must be called by the UIApplicationDelegate's
 * application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler
 *
 * Note: This method is relevant only for apps targeting iOS 8 and iOS 9.
 *
 * @param application The application instance.
 * @param identifier The action identifier.
 * @param userInfo The remote notification.
 * @param responseInfo The user response info.
 * @param handler The completion handler
 */
+ (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:(nullable NSDictionary *)responseInfo completionHandler:(void (^)())handler;

@end

NS_ASSUME_NONNULL_END

