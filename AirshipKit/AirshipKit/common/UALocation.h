/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "UAComponent.h"

/**
 * Location delegate protocol to receive callbacks for location updates.
 */
@protocol UALocationDelegate <NSObject>

NS_ASSUME_NONNULL_BEGIN

@optional

///---------------------------------------------------------------------------------------
/// @name Location Delegate Optional Methods
///---------------------------------------------------------------------------------------

/**
 * Called when location updates started.
 */
- (void)locationUpdatesStarted;

/**
 * Called when location updates stopped. Location updates will stop
 * if the application background and `isBackgroundLocationUpdatesAllowed` is set
 * to NO, if the user disables location, or if location updates are disabled with
 * `locationUpdatesEnabled`.
 */
- (void)locationUpdatesStopped;

/**
 * Called when new location updates are available. The last location will
 * automatically generate a location event.
 */
- (void)receivedLocationUpdates:(NSArray *)locations;

@end

/**
 * Main class for interacting with Urban Airship location. Used to send location
 * updates for the user to Urban Airship.
 */
@interface UALocation : UAComponent

///---------------------------------------------------------------------------------------
/// @name Location Properties
///---------------------------------------------------------------------------------------

/**
 * Flag to enable/disable requesting location authorization when the location service
 * needs to start. Defaults to `YES`.
 */
@property (nonatomic, assign, getter=isAutoRequestAuthorizationEnabled) BOOL autoRequestAuthorizationEnabled;

/**
 * Flag to enable/disable location updates. Defaults to `NO`.
 */
@property (nonatomic, assign, getter=isLocationUpdatesEnabled) BOOL locationUpdatesEnabled;

/**
 * Flag to allow/disallow location updates in the background. Defaults to `NO`.
 */
@property (nonatomic, assign, getter=isBackgroundLocationUpdatesAllowed) BOOL backgroundLocationUpdatesAllowed;

/**
 * UALocationDelegate to receive location callbacks.
 */
@property (nonatomic, weak, nullable) id <UALocationDelegate> delegate;

/**
 * Returns the last received location. Can be nil if no location has been received.
 */
@property (nonatomic, readonly, nullable) CLLocation *lastLocation;

///---------------------------------------------------------------------------------------
/// @name Location Methods
///---------------------------------------------------------------------------------------

/**
 * Check if user has opted in to location updates.
 *
 * @return YES if UALocation location updates are enabled and the user has authorized the app to use location services
 */
- (BOOL)isLocationOptedIn;

/**
 * Check if user has denied the app's request to use location services.
 *
 * @return YES if UALocation location updates are enabled and the user has authorized the app to use location services
 */
- (BOOL)isLocationDeniedOrRestricted;

/**
 * Return a string describing the app's authorization status for location services.
 *
 * @return NSString describing the app's authorization status for location services
 */
- (NSString *)locationPermissionDescription;

NS_ASSUME_NONNULL_END

@end

