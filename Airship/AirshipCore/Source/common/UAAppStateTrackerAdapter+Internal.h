/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAApplicationState.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for app state tracker callbacks.
 */
@protocol UAAppStateTrackerDelegate <NSObject>

/**
 * The application finished launching.
 *
 * @param remoteNotification The remote notification that launched the app.
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
@protocol UAAppStateTrackerAdapter <NSObject>

/**
 * The current application state.
 */
@property(nonatomic, readonly) UAApplicationState state;

/**
 * The state tracker delegate.
 */
@property(nonatomic, weak) id<UAAppStateTrackerDelegate> stateTrackerDelegate;

/**
 * Creates an app state tracker.
 *
 * @return The tracker.
 */
+ (id<UAAppStateTrackerAdapter>)adapter;


@end

NS_ASSUME_NONNULL_END
