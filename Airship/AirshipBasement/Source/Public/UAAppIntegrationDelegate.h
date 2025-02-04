/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * App integration delegate.
 * @note For internal use only. :nodoc:
 */
NS_SWIFT_NAME(AppIntegrationDelegate)
NS_SWIFT_SENDABLE
NS_SWIFT_UI_ACTOR
@protocol UAAppIntegrationDelegate <NSObject>

- (void)onBackgroundAppRefresh;

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken NS_SWIFT_NAME(didRegisterForRemoteNotifications(deviceToken:));

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error NS_SWIFT_NAME(didFailToRegisterForRemoteNotifications(error:));

#if !TARGET_OS_WATCH
- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo
                        isForeground:(BOOL)isForeground
                   completionHandler:(NS_SWIFT_SENDABLE void (^)(UIBackgroundFetchResult))completionHandler NS_SWIFT_ASYNC_NAME(didReceiveRemoteNotification(userInfo:isForeground:)) NS_SWIFT_ASYNC(3);

#else
- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo
                        isForeground:(BOOL)isForeground
                   completionHandler:(NS_SWIFT_SENDABLE void (^)(WKBackgroundFetchResult))completionHandler NS_SWIFT_ASYNC_NAME(didReceiveRemoteNotification(userInfo:isForeground:)) NS_SWIFT_ASYNC(3);

#endif

- (void)willPresentNotification:(UNNotification *)notification
            presentationOptions:(UNNotificationPresentationOptions)options
              completionHandler:(NS_SWIFT_SENDABLE void (^)(void))completionHandler NS_SWIFT_ASYNC_NAME(willPresentNotification(notification:presentationOptions:)) NS_SWIFT_ASYNC(3);


- (void)didReceiveNotificationResponse:(UNNotificationResponse *)response completionHandler:(NS_SWIFT_SENDABLE void (^)(void))completionHandler API_UNAVAILABLE(tvos) NS_SWIFT_ASYNC_NAME(didReceiveNotificationResponse(response:)) NS_SWIFT_ASYNC(2);

- (void)presentationOptionsForNotification:(UNNotification *)notification completionHandler:(NS_SWIFT_SENDABLE void (^)(UNNotificationPresentationOptions))completionHandler
NS_SWIFT_ASYNC_NAME(presentationOptionsForNotification(_:)) NS_SWIFT_ASYNC(2);

@end


NS_ASSUME_NONNULL_END

