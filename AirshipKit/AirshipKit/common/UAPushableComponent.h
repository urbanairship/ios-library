#import <Foundation/Foundation.h>
#import "UANotificationResponse.h"
#import "UANotificationContent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal protocol to fan out push handling to UAComponents.
 */
@protocol UAPushableComponent

@optional

/**
 * Called when a remote notification is received.
 * @param notification The notification.
 * @param completionHandler The completion handler that must be called with the fetch result.
 */
-(void)receivedRemoteNotification:(UANotificationContent *)notification completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

/**
 * Called when a notification response is received.
 * @param response The notification response.
 * @param completionHandler The completion handler that must be called after processing the response.
*/
-(void)receivedNotificationResponse:(UANotificationResponse *)response completionHandler:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
