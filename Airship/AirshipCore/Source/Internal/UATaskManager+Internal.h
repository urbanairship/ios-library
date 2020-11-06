/* Copyright Airship and Contributors */

#import "UATaskManager.h"
#import "UANetworkMonitor+Internal.h"

@interface UATaskManager()

/**
 * Factory method. Used for testing.
 * @param application The application.
 * @param notificationCenter The notification center.
 * @param dispatcher The dispatcher used to schedule/retry tasks.
 * @param networkMonitor A network monitor instance.
 */
+ (instancetype)taskManagerWithApplication:(UIApplication *)application
                        notificationCenter:(NSNotificationCenter *)notificationCenter
                                dispatcher:(UADispatcher *)dispatcher
                            networkMonitor:(UANetworkMonitor *)networkMonitor;

@end
