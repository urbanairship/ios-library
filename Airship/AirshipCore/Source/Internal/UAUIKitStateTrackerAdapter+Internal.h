/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

#import "UAAppStateTrackerAdapter+Internal.h"
#import "UADispatcher.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAUIKitStateTrackerAdapter : NSObject <UAAppStateTrackerAdapter>

/**
 * Creates an app state tracker. Used for testing.
 *
 * @param notificationCenter The notification center.
 * @param dispatcher The main dispatcher.
 * @return The tracker.
 */
+ (id<UAAppStateTrackerAdapter>)adapterWithNotificationCenter:(NSNotificationCenter *)notificationCenter dispatcher:(UADispatcher *)dispatcher;

@end

NS_ASSUME_NONNULL_END
