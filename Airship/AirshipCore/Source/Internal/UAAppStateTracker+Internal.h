/* Copyright Airship and Contributors */

#import "UAAppStateTracker.h"
#import "UAAppStateTrackerAdapter+Internal.h"
#import "UAUIKitStateTrackerAdapter+Internal.h"

@interface UAAppStateTracker() <UAAppStateTrackerDelegate>

/**
 * UAAppStateTracker initializer. Used for testing.
 *
 * @param notificationCenter The notification center.
 * @param adapter The app state tracker adapter.
 * @return The adapter.
 */
- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter adapter:(id<UAAppStateTrackerAdapter>)adapter;

@end
