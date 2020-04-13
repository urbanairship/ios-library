/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEvent.h"

@class UAProximityRegion;
@class UACircularRegion;

NS_ASSUME_NONNULL_BEGIN

/**
 * Type of the region event.
 */
extern NSString * const UARegionEventType;

/**
 * Maximum latitude for a region event.
 */
extern double const UARegionEventMaxLatitude;

/**
 * Minimum latitude for a region event.
 */
extern double const UARegionEventMinLatitude;

/**
 * Maximum longitude for a region event.
 */
extern double const UARegionEventMaxLongitude;

/**
 * Minimum longitude for a region event.
 */
extern double const UARegionEventMinLongitude;

/**
 * Maximum number of characters for strings in a region event.
 */
extern NSUInteger const UARegionEventMaxCharacters;

/**
 * Minimum number of characters for strings in a region event.
 */
extern NSUInteger const UARegionEventMinCharacters;

/**
 * Key for the source of the region event.
 */
extern NSString * const UARegionSourceKey;

/**
 * Key for the id of the region event.
 */
extern NSString * const UARegionIDKey;

/**
 * Key for the type of a boundary event.
 */
extern NSString * const UARegionBoundaryEventKey;

/**
 * Value when entering a boundary.
 */
extern NSString * const UARegionBoundaryEventEnterValue;

/**
 * Value when exiting a boundary.
 */
extern NSString * const UARegionBoundaryEventExitValue;

/**
 * Key for the latitude of the region event.
 */
extern NSString * const UARegionLatitudeKey;

/**
 * Key for the longitude of the region event.
 */
extern NSString * const UARegionLongitudeKey;

/**
 * Key for the proximity dictionary of the region event.
 */
extern NSString * const UAProximityRegionKey;

/**
 * Key for the proximity region id of the region event.
 */
extern NSString * const UAProximityRegionIDKey;

/**
 * Key for the proximity major of th region event.
 */
extern NSString * const UAProximityRegionMajorKey;

/**
 * Key for the proximity minor of th region event.
 */
extern NSString * const UAProximityRegionMinorKey;

/**
 * Key for the proximity RSSI of the region event.
 */
extern NSString * const UAProximityRegionRSSIKey;

/**
 * Key for the circular region dictionary of the region event.
 */
extern NSString * const UACircularRegionKey;

/**
 * Key for the radius of the circular region of the region event.
 */
extern NSString * const UACircularRegionRadiusKey;

/**
 * Type of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionEventType.
*/
extern NSString * const kUARegionEventType DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionEventType.");

/**
 * Maximum latitude for a region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxLatitude.
*/
extern double const kUARegionEventMaxLatitude DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxLatitude.");

/**
 * Minimum latitude for a region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinLatitude.
*/
extern double const kUARegionEventMinLatitude DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinLatitude.");

/**
 * Maximum longitude for a region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxLongitude.
*/
extern double const kUARegionEventMaxLongitude DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxLongitude.");

/**
 * Minimum longitude for a region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinLongitude.
*/
extern double const kUARegionEventMinLongitude DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinLongitude.");

/**
 * Maximum number of characters for strings in a region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxCharacters.
*/
extern NSUInteger const kUARegionEventMaxCharacters DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxCharacters.");

/**
 * Minimum number of characters for strings in a region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinCharacters.
*/
extern NSUInteger const kUARegionEventMinCharacters DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinCharacters.");

/**
 * Key for the source of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionSourceKey.
*/
extern NSString * const kUARegionSourceKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionSourceKey.");

/**
 *
 * Key for the id of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionIDKey.
*/
extern NSString * const kUARegionIDKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionIDKey.");

/**
 * Key for the type of a boundary event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventKey.
*/
extern NSString * const kUARegionBoundaryEventKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventKey.");

/**
 * Value when entering a boundary.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventEnterValue.
*/
extern NSString * const kUARegionBoundaryEventEnterValue DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventEnterValue.");

/**
 * Value when exiting a boundary.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventExitValue.
*/
extern NSString * const kUARegionBoundaryEventExitValue DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventExitValue.");

/**
 * Key for the latitude of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionLatitudeKey.
*/
extern NSString * const kUARegionLatitudeKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionLatitudeKey.");

/**
 * Key for the longitude of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UARegionLongitudeKey.
*/
extern NSString * const kUARegionLongitudeKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UARegionLongitudeKey.");

/**
 * Key for the proximity dictionary of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionKey.
*/
extern NSString * const kUAProximityRegionKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionKey.");

/**
 * Key for the proximity region id of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionIDKey.
*/
extern NSString * const kUAProximityRegionIDKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionIDKey.");

/**
 * Key for the proximity major of th region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMajorKey.
*/
extern NSString * const kUAProximityRegionMajorKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMajorKey.");

/**
 * Key for the proximity minor of th region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMinorKey.
*/
extern NSString * const kUAProximityRegionMinorKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMinorKey.");

/**
 * Key for the proximity RSSI of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionRSSIKey.
*/
extern NSString * const kUAProximityRegionRSSIKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionRSSIKey.");

/**
 * Key for the circular region dictionary of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionKey.
*/
extern NSString * const kUACircularRegionKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionKey.");

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

/**
 * Key for the radius of the circular region of the region event.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionRadiusKey.
*/
extern NSString * const kUACircularRegionRadiusKey DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionRadiusKey.");


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
