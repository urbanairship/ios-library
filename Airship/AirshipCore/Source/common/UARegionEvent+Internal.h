/* Copyright Airship and Contributors */

#import "UARegionEvent.h"


NS_ASSUME_NONNULL_BEGIN

/**
 * Key for the id of the region event.
 */
extern NSString * const UARegionIDKey;

/**
 * Value when entering a boundary.
 */
extern NSString * const UARegionBoundaryEventEnterValue;

/**
 * Value when exiting a boundary.
 */
extern NSString * const UARegionBoundaryEventExitValue;

/*
 * SDK-private extensions to UARegionEvent
 */
@interface UARegionEvent ()

/**
 * The source of the event.
 */
@property (nonatomic, copy) NSString *source;

/**
 * The region's identifier.
 */
@property (nonatomic, copy) NSString *regionID;

/**
 * The type of boundary event - enter, exit or unknown.
 */
@property (nonatomic, assign) UABoundaryEvent boundaryEvent;

/**
 * Validates region event RSSI.
 */
+ (BOOL)regionEventRSSIIsValid:(nullable NSNumber *)RSSI;

/**
 * Validates region event radius.
 */
+ (BOOL)regionEventRadiusIsValid:(nullable NSNumber *)radius;

/**
 * Validates region event latitude.
 */
+ (BOOL)regionEventLatitudeIsValid:(nullable NSNumber *)latitude;

/**
 * Validates region event longitude.
 */
+ (BOOL)regionEventLongitudeIsValid:(nullable NSNumber *)longitude;

/**
 * Validates region event character count.
 */
+ (BOOL)regionEventCharacterCountIsValid:(nullable NSString *)string;


@end

NS_ASSUME_NONNULL_END
