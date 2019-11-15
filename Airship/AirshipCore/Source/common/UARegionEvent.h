/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEvent.h"

#define kUARegionEventType @"region_event"

#define kUARegionEventMaxLatitude 90
#define kUARegionEventMinLatitude -90
#define kUARegionEventMaxLongitude 180
#define kUARegionEventMinLongitude -180
#define kUARegionEventMaxCharacters 255
#define kUARegionEventMinCharacters 1

#define kUARegionSourceKey @"source"
#define kUARegionIDKey @"region_id"
#define kUARegionBoundaryEventKey @"action"
#define kUARegionBoundaryEventEnterValue @"enter"
#define kUARegionBoundaryEventExitValue @"exit"
#define kUARegionLatitudeKey @"latitude"
#define kUARegionLongitudeKey @"longitude"

#define kUAProximityRegionKey @"proximity"
#define kUAProximityRegionIDKey @"proximity_id"
#define kUAProximityRegionMajorKey @"major"
#define kUAProximityRegionMinorKey @"minor"
#define kUAProximityRegionRSSIKey @"rssi"

#define kUACircularRegionKey @"circular_region"
#define kUACircularRegionRadiusKey @"radius"


@class UAProximityRegion;
@class UACircularRegion;

/**
 * Represents the boundary crossing event type.
 */
typedef NS_ENUM(NSInteger, UABoundaryEvent) {
    /**
     * Enter event
     */
    UABoundaryEventEnter = 1,

    /**
     * Exit event
     */
    UABoundaryEventExit = 2,
};

NS_ASSUME_NONNULL_BEGIN

/**
 * A UARegion event captures information regarding a region event for
 * UAAnalytics.
 */
@interface UARegionEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name Region Event Properties
///---------------------------------------------------------------------------------------

/**
 * A proximity region with an identifier, major and minor.
 */
@property (nonatomic, strong, nullable) UAProximityRegion *proximityRegion;

/**
 * A circular region with a radius, and latitude/longitude from its center.
 */
@property (nonatomic, strong, nullable) UACircularRegion *circularRegion;

/**
 * The type of boundary event - enter, exit or unknown.
 */
@property (nonatomic, readonly) UABoundaryEvent boundaryEvent;

/**
 * The source of the event.
 */
@property (nonatomic, readonly) NSString *source;

/**
 * The region's identifier.
 */
@property (nonatomic, readonly) NSString *regionID;

/**
 * The event's JSON payload.
 */
@property (nonatomic, readonly) NSDictionary *payload;


///---------------------------------------------------------------------------------------
/// @name Region Event Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method for creating a region event.
 *
 * @param regionID The ID of the region.
 * @param source The source of the event.
 * @param boundaryEvent The type of boundary crossing event.
 *
 * @return Region event object or `nil` if error occurs.
 */
+ (nullable instancetype)regionEventWithRegionID:(NSString *)regionID
                                          source:(NSString *)source
                                   boundaryEvent:(UABoundaryEvent)boundaryEvent;

@end

NS_ASSUME_NONNULL_END
