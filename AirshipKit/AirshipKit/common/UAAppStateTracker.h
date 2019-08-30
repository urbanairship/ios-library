/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAApplicationState.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for app state tracker callbacks. These methods directly correspond to those
 * on UIApplicationDelegate, with a few additions for custom use cases.
 */
@protocol UAAppStateTrackerDelegate <NSObject>
@optional

/**
 * The application finished launching.
 *
 * @param remoteNotification The remote notification that launched the app. If nil, the app was not launched by a remote notification.
 */
- (void)applicationDidFinishLaunching:(nullable NSDictionary *)remoteNotification;

/**
 * The application became active.
 */
- (void)applicationDidBecomeActive;

/**
 * The application is about to become active.
 */
- (void)applicationWillEnterForeground;

/**
 * The application entered the background.
 */
- (void)applicationDidEnterBackground;

/**
 * The application fully transitioned from a background state into the active state.
 */
- (void)applicationDidTransitionToForeground;

/**
 * The application fully transitioned from a foreground state into the background state.
 */
- (void)applicationDidTransitionToBackground;

/**
 * The application is about to leave the active state.
 */
- (void)applicationWillResignActive;

/**
 * The application is about to terminate.
 */
- (void)applicationWillTerminate;

@end

/**
 * Protocol for tracking application state. Classes implementing this protocol should be able to report
 * current application state, and send callbacks to an optional delegate object implementing the UAAppStateTrackerDelegate
 * protocol.
 */
@protocol UAAppStateTracker <NSObject>

/**
 * The current application state.
 */
@property(nonatomic, readonly) UAApplicationState state;

/**
 * The state tracker delegate.
 */
@property(nonatomic, weak) id<UAAppStateTrackerDelegate> stateTrackerDelegate;

@end

NS_ASSUME_NONNULL_END
