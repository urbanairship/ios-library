/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UARegionEvent.h"

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

NS_ASSUME_NONNULL_BEGIN

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

/**
 * The event's JSON payload. Used for automation.
 */
@property (nonatomic, readonly) NSDictionary *payload;

@end

NS_ASSUME_NONNULL_END
