/* Copyright Airship and Contributors */

#import <AirshipCore/AirshipCore.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Applicaiton lifecycle tracker used for testing.
 * @note For internal use only. :nodoc:
 */
@interface UATestAppStateTracker : UAAppStateTracker

/**
 * The current application state, used for testing.
 */
@property(nonatomic, assign) UAApplicationState currentState;

@end

NS_ASSUME_NONNULL_END
