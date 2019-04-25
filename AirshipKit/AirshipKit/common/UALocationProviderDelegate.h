/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Enum of location provider permission statuses.
 */
typedef NS_ENUM(NSUInteger, UALocationProviderPermissionStatus) {
    /**
     * Location is disabled in the provider.
     */
    UALocationProviderPermissionStatusDisabled,
    /**
     * The user has not yet been prompted for location permissions.
     */
    UALocationProviderPermissionStatusUnprompted,
    /**
     * Location permissions have not been allowed by the user.
     */
    UALocationProviderPermissionStatusNotAllowed,
    /**
     * The user has granted foreground location permiossions.
     */
    UALocationProviderPermissionStatusForegroundAllowed,
    /**
     * The user has granted both foreground and background location permissions.
     */
    UALocationProviderPermissionStatusAlwaysAllowed
};

/**
 * Protocol for bridging location providers with the SDK.
 */
@protocol UALocationProviderDelegate <NSObject>

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

/**
 * Returns an enum representing the app's authorization status for location services.
 *
 * @return The location permission status.
 */
- (UALocationProviderPermissionStatus)locationPermissionStatus;

@end

NS_ASSUME_NONNULL_END
