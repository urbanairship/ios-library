/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "UAEvent.h"

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

/**
 * A proximity region with an identifier, major and minor.
 */
@property (nonatomic, strong, nullable) UAProximityRegion *proximityRegion;

/**
 * A circular region with a radius, and latitude/longitude from its center.
 */
@property (nonatomic, strong, nullable) UACircularRegion *circularRegion;

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
