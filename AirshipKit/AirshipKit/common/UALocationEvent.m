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

#import "UALocationEvent.h"
#import "UAEvent+Internal.h"

@implementation UALocationEvent

UALocationEventAnalyticsKey * const UALocationEventForegroundKey = @"foreground";
UALocationEventAnalyticsKey * const UALocationEventLatitudeKey = @"lat";
UALocationEventAnalyticsKey * const UALocationEventLongitudeKey = @"long";
UALocationEventAnalyticsKey * const UALocationEventDesiredAccuracyKey = @"requested_accuracy";
UALocationEventAnalyticsKey * const UALocationEventUpdateTypeKey = @"update_type";
UALocationEventAnalyticsKey * const UALocationEventProviderKey = @"provider";
UALocationEventAnalyticsKey * const UALocationEventDistanceFilterKey = @"update_dist";
UALocationEventAnalyticsKey * const UALocationEventHorizontalAccuracyKey = @"h_accuracy";
UALocationEventAnalyticsKey * const UALocationEventVerticalAccuracyKey = @"v_accuracy";

UALocationEventUpdateType * const UALocationEventAnalyticsType = @"location";
UALocationEventUpdateType * const UALocationEventUpdateTypeChange = @"CHANGE";
UALocationEventUpdateType * const UALocationEventUpdateTypeContinuous = @"CONTINUOUS";
UALocationEventUpdateType * const UALocationEventUpdateTypeSingle = @"SINGLE";
UALocationEventUpdateType * const UALocationEventUpdateTypeNone = @"NONE";

UALocationServiceProviderType *const UALocationServiceProviderGps = @"GPS";
UALocationServiceProviderType *const UALocationServiceProviderNetwork = @"NETWORK";
UALocationServiceProviderType *const UALocationServiceProviderUnknown = @"UNKNOWN";

NSString * const UAAnalyticsValueNone = @"NONE";

+ (UALocationEvent *)locationEventWithLocation:(CLLocation *)location
                                  providerType:(UALocationServiceProviderType *)providerType
                               desiredAccuracy:(NSNumber *)desiredAccuracy
                                distanceFilter:(NSNumber *)distanceFilter
                                    updateType:(UALocationEventUpdateType *)updateType {

    UALocationEvent *event = [[UALocationEvent alloc] init];
    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    [data setValue:updateType forKey:UALocationEventUpdateTypeKey];
    [data setValue:[NSString stringWithFormat:@"%.7f", location.coordinate.latitude] forKey:UALocationEventLatitudeKey];
    [data setValue:[NSString stringWithFormat:@"%.7f", location.coordinate.longitude] forKey:UALocationEventLongitudeKey];
    [data setValue:[NSString stringWithFormat:@"%i", (int)location.horizontalAccuracy] forKey:UALocationEventHorizontalAccuracyKey];
    [data setValue:[NSString stringWithFormat:@"%i", (int)location.verticalAccuracy] forKey:UALocationEventVerticalAccuracyKey];

    if (providerType) {
        [data setValue:providerType forKey:UALocationEventProviderKey];
    } else {
        [data setValue:UALocationServiceProviderUnknown forKey:UALocationEventProviderKey];
    }

    if (desiredAccuracy) {
        [data setValue:[NSString stringWithFormat:@"%i", [desiredAccuracy intValue]] forKey:UALocationEventDesiredAccuracyKey];
    } else {
        [data setValue:UAAnalyticsValueNone forKey:UALocationEventDesiredAccuracyKey];
    }

    if (distanceFilter) {
        [data setValue:[NSString stringWithFormat:@"%i", [distanceFilter intValue]] forKey:UALocationEventDistanceFilterKey];
    } else {
        [data setValue:UAAnalyticsValueNone forKey:UALocationEventDistanceFilterKey];
    }

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        [data setValue:@"true" forKey:UALocationEventForegroundKey];
    } else {
        [data setValue:@"false" forKey:UALocationEventForegroundKey];
    }

    event.data = [data mutableCopy];
    return event;
}

+ (UALocationEvent *)locationEventWithLocation:(CLLocation *)location
                                  providerType:(UALocationServiceProviderType *)providerType
                               desiredAccuracy:(NSNumber *)desiredAccuracy
                                distanceFilter:(NSNumber *)distanceFilter {

    return [UALocationEvent locationEventWithLocation:location
                                         providerType:providerType
                                      desiredAccuracy:desiredAccuracy
                                       distanceFilter:distanceFilter
                                           updateType:UALocationEventUpdateTypeNone];

}

+ (UALocationEvent *)singleLocationEventWithLocation:(CLLocation *)location
                                        providerType:(UALocationServiceProviderType *)providerType
                                     desiredAccuracy:(NSNumber *)desiredAccuracy
                                      distanceFilter:(NSNumber *)distanceFilter {

    return [UALocationEvent locationEventWithLocation:location
                                         providerType:providerType
                                      desiredAccuracy:desiredAccuracy
                                       distanceFilter:distanceFilter
                                           updateType:UALocationEventUpdateTypeSingle];
}

+ (UALocationEvent *)significantChangeLocationEventWithLocation:(CLLocation *)location
                                                   providerType:(UALocationServiceProviderType *)providerType {

    return [UALocationEvent locationEventWithLocation:location
                                         providerType:providerType
                                      desiredAccuracy:nil
                                       distanceFilter:nil
                                           updateType:UALocationEventUpdateTypeChange];

}

+ (UALocationEvent *)standardLocationEventWithLocation:(CLLocation *)location
                                          providerType:(UALocationServiceProviderType *)providerType
                                       desiredAccuracy:(NSNumber *)desiredAccuracy
                                        distanceFilter:(NSNumber *)distanceFilter {

    return [UALocationEvent locationEventWithLocation:location
                                         providerType:providerType
                                      desiredAccuracy:desiredAccuracy
                                       distanceFilter:distanceFilter
                                           updateType:UALocationEventUpdateTypeContinuous];

}

- (NSString *)eventType {
    return UALocationEventAnalyticsType;
}

- (UAEventPriority)priority {
    return UAEventPriorityLow;
}


@end
