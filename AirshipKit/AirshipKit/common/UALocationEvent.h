/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAEvent.h"

@protocol UALocationProviderProtocol;

NS_ASSUME_NONNULL_BEGIN

/** Keys and values for location analytics */
typedef NSString UALocationEventAnalyticsKey;
extern UALocationEventAnalyticsKey * const UALocationEventForegroundKey;
extern UALocationEventAnalyticsKey * const UALocationEventLatitudeKey;
extern UALocationEventAnalyticsKey * const UALocationEventLongitudeKey;
extern UALocationEventAnalyticsKey * const UALocationEventDesiredAccuracyKey;
extern UALocationEventAnalyticsKey * const UALocationEventUpdateTypeKey;
extern UALocationEventAnalyticsKey * const UALocationEventProviderKey;
extern UALocationEventAnalyticsKey * const UALocationEventDistanceFilterKey;
extern UALocationEventAnalyticsKey * const UALocationEventHorizontalAccuracyKey;
extern UALocationEventAnalyticsKey * const UALocationEventVerticalAccuracyKey;

typedef NSString UALocationEventUpdateType;
extern UALocationEventUpdateType * const UALocationEventAnalyticsType;
extern UALocationEventUpdateType * const UALocationEventUpdateTypeChange;
extern UALocationEventUpdateType * const UALocationEventUpdateTypeContinuous;
extern UALocationEventUpdateType * const UALocationEventUpdateTypeSingle;
extern UALocationEventUpdateType * const UALocationEventUpdateTypeNone;

typedef NSString UALocationServiceProviderType;
extern UALocationServiceProviderType *const UALocationServiceProviderGps;
extern UALocationServiceProviderType *const UALocationServiceProviderNetwork;
extern UALocationServiceProviderType *const UALocationServiceProviderUnknown;

extern NSString * const UAAnalyticsValueNone;

/**
 * Model object for location information.
 */
@interface UALocationInfo : NSObject

/**
 * The latitude.
 */
@property (nonatomic, readonly) double latitude;

/**
 * The longitude.
 */
@property (nonatomic, readonly) double longitude;

/**
 * The horizontal accuracy.
 */
@property (nonatomic, readonly) double horizontalAccuracy;

/**
 * The vertical accuracy.
 */
@property (nonatomic, readonly) double verticalAccuracy;

/**
 * UALocationEvent class factory method.
 *
 * @param latitude The latitude.
 * @param longitude The longitude.
 * @param horizontalAccuracy The horizontal accuracy.
 * @param verticalAccuracy The vertical accuracy.
 */
+ (instancetype)infoWithLatitude:(double)latitude
                       longitude:(double)longitude
              horizontalAccuracy:(double)horizontalAccuracy
                verticalAccuracy:(double)verticalAccuracy;

@end

/** 
 * A UALocationEvent captures all the necessary information for
 * UAAnalytics.
 */
@interface UALocationEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name Location Event Factories
///---------------------------------------------------------------------------------------

/**
 * Creates a UALocationEvent.
 *
 * @param info The location info.
 * @param providerType The type of provider that produced the location.
 * @param desiredAccuracy The requested accuracy.
 * @param distanceFilter The requested distance filter.
 *
 * @return UALocationEvent populated with the necessary values.
 */
+ (UALocationEvent *)locationEventWithInfo:(UALocationInfo *)info
                              providerType:(nullable UALocationServiceProviderType *)providerType
                           desiredAccuracy:(nullable NSNumber *)desiredAccuracy
                            distanceFilter:(nullable NSNumber *)distanceFilter;

/**
 * Creates a UALocationEvent for a single location update.
 *
 * @param info The location info.
 * @param providerType The type of provider that produced the location.
 * @param desiredAccuracy The requested accuracy.
 * @param distanceFilter The requested distance filter.
 *
 * @return UALocationEvent populated with the necessary values
 */
+ (UALocationEvent *)singleLocationEventWithInfo:(UALocationInfo *)info
                                    providerType:(nullable UALocationServiceProviderType *)providerType
                                 desiredAccuracy:(nullable NSNumber *)desiredAccuracy
                                  distanceFilter:(nullable NSNumber *)distanceFilter;


/**
 * Creates a UALocationEvent for a significant location change.
 *
 * @param info The location info.
 * @param providerType The type of provider that produced the location.
 *
 * @return UALocationEvent populated with the necessary values
 */
+ (UALocationEvent *)significantChangeLocationEventWithInfo:(UALocationInfo *)info
                                               providerType:(nullable UALocationServiceProviderType *)providerType;

/**
 * Creates a UALocationEvent for a standard location change.
 *
 * @param info The location info.
 * @param providerType The type of provider that produced the location.
 * @param desiredAccuracy The requested accuracy.
 * @param distanceFilter The requested distance filter.
 *
 * @return UALocationEvent populated with the necessary values.
 */
+ (UALocationEvent *)standardLocationEventWithInfo:(UALocationInfo *)info
                                      providerType:(nullable UALocationServiceProviderType *)providerType
                                   desiredAccuracy:(nullable NSNumber *)desiredAccuracy
                                    distanceFilter:(nullable NSNumber *)distanceFilter;


NS_ASSUME_NONNULL_END

@end
