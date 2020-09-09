/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAApplicationState.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * NSNotification when the application finished launching.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAApplicationDidFinishLaunchingNotification;

/**
 * NSNotification when the application became active.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAApplicationDidBecomeActiveNotification;

/**
 * NSNotification when the application is about to become active.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAApplicationWillEnterForegroundNotification;

/**
 * NSNotification when the application entered the background.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAApplicationDidEnterBackgroundNotification;

/**
 * NSNotification when the application is about to leave the active state.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAApplicationWillResignActiveNotification;

/**
 * NSNotification when the application is about to terminate.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAApplicationWillTerminateNotification;

/**
 * NSNotification when the application fully transitioned from a foreground state into the background state.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAApplicationDidTransitionToBackground;

/**
 * NSNotification when the application fully transitioned from a background state into the foreground state.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAApplicationDidTransitionToForeground;

/**
 * The value of this key is an NSDictionary containing the payload of the remote notification for `UAApplicationDidFinishLaunchingNotification`.
 * The key and the dictionary are found in the top-level of the UAApplicationDidFinishLaunchingNotification's userInfo dictionary.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UAApplicationLaunchOptionsRemoteNotificationKey;

/**
 * Applicaiton lifecycle tracker.
 * @note For internal use only. :nodoc:
 */
@interface UAAppStateTracker : NSObject

/**
 * The current application state.
 */
@property(nonatomic, readonly) UAApplicationState state;

/**
 * Gets the shared instance.
 * @return the shared instance.
 */
+ (instancetype)shared;

@end

NS_ASSUME_NONNULL_END
