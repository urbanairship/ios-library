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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

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
 * A UALocationEvent captures all the necessary information for
 * UAAnalytics.
 */
@interface UALocationEvent : UAEvent

/**
 * Creates a UALocationEvent.
 *
 * @param location Location going to UAAnalytics
 * @param providerType The type of provider that produced the location
 * @param desiredAccuracy The requested accuracy.
 * @param distanceFilter The requested distance filter.
 * @return UALocationEvent populated with the necessary values
 */
+ (UALocationEvent *)locationEventWithLocation:(CLLocation *)location
                                  providerType:(nullable UALocationServiceProviderType *)providerType
                               desiredAccuracy:(nullable NSNumber *)desiredAccuracy
                                distanceFilter:(nullable NSNumber *)distanceFilter;


/**
 * Creates a UALocationEvent for a single location update.
 *
 * @param location Location going to UAAnalytics
 * @param providerType The type of provider that produced the location
 * @param desiredAccuracy The requested accuracy.
 * @param distanceFilter The requested distance filter.
 * @return UALocationEvent populated with the necessary values
 */
+ (UALocationEvent *)singleLocationEventWithLocation:(CLLocation *)location
                                        providerType:(nullable UALocationServiceProviderType *)providerType
                                     desiredAccuracy:(nullable NSNumber *)desiredAccuracy
                                      distanceFilter:(nullable NSNumber *)distanceFilter;


/**
 * Creates a UALocationEvent for a significant location change.
 *
 * @param location Location going to UAAnalytics
 * @param providerType The type of provider that produced the location
 * @return UALocationEvent populated with the necessary values
 */
+ (UALocationEvent *)significantChangeLocationEventWithLocation:(CLLocation *)location
                                                   providerType:(nullable UALocationServiceProviderType *)providerType;

/**
 * Creates a UALocationEvent for a standard location change.
 *
 * @param location Location going to UAAnalytics
 * @param providerType The type of provider that produced the location
 * @param desiredAccuracy The requested accuracy.
 * @param distanceFilter The requested distance filter.
 * @return UALocationEvent populated with the necessary values
 */
+ (UALocationEvent *)standardLocationEventWithLocation:(CLLocation *)location
                                          providerType:(nullable UALocationServiceProviderType *)providerType
                                       desiredAccuracy:(nullable NSNumber *)desiredAccuracy
                                        distanceFilter:(nullable NSNumber *)distanceFilter;


NS_ASSUME_NONNULL_END

@end
