/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAppStateTracker.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Factory class for creating platform-specific concrete implementations of the UAAppStateTracker protocol.
 */
@interface UAAppStateTrackerFactory : NSObject

/**
 * Creates an app state tracker.
 *
 * @return The tracker.
 */
+ (id<UAAppStateTracker>)tracker;

@end

NS_ASSUME_NONNULL_END
