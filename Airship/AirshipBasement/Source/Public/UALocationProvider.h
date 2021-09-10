/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/**
 * Protocol for bridging location providers with the SDK.
 * @note For internal use only. :nodoc:
 */
@protocol UALocationProvider <NSObject>

/**
 * Flag to enable/disable location updates.
 */
@property (nonatomic, assign, getter=isLocationUpdatesEnabled) BOOL locationUpdatesEnabled;

/**
 * Flag to allow/disallow location updates in the background.
 */
@property (nonatomic, assign, getter=isBackgroundLocationUpdatesAllowed) BOOL backgroundLocationUpdatesAllowed;

/**
 * Check if the user has opted in to location updates.
 *
 * @return `YES` if location updates are enabled and the user has authorized the app to use location services.
 */
- (BOOL)isLocationOptedIn;

/**
 * Check if the user has denied or restricted the app's request to use location services.
 *
 * @return `YES` if the user has denied or restricted the app's request to use location services.
 */
- (BOOL)isLocationDeniedOrRestricted;

@end


NS_ASSUME_NONNULL_END
