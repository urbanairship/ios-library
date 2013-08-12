/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAAnalytics.h"

@implementation UALocationEvent

#pragma mark -
#pragma mark UALocationAnalyticsKey Values

UALocationEventAnalyticsKey * const UALocationEventSessionIDKey = @"session_id";
UALocationEventAnalyticsKey * const UALocationEventForegroundKey = @"foreground";
UALocationEventAnalyticsKey * const UALocationEventLatitudeKey = @"lat";
UALocationEventAnalyticsKey * const UALocationEventLongitudeKey = @"long";
UALocationEventAnalyticsKey * const UALocationEventDesiredAccuracyKey = @"requested_accuracy";
UALocationEventAnalyticsKey * const UALocationEventUpdateTypeKey = @"update_type";
UALocationEventAnalyticsKey * const UALocationEventProviderKey = @"provider";
UALocationEventAnalyticsKey * const UALocationEventDistanceFilterKey = @"update_dist";
UALocationEventAnalyticsKey * const UALocationEventHorizontalAccuracyKey = @"h_accuracy";
UALocationEventAnalyticsKey * const UALocationEventVerticalAccuracyKey = @"v_accuracy";

#pragma mark -
#pragma mark UALocationEventUpdateType

UALocationEventUpdateType * const UALocationEventAnalyticsType = @"location";
UALocationEventUpdateType * const UALocationEventUpdateTypeChange = @"CHANGE";
UALocationEventUpdateType * const UALocationEventUpdateTypeContinuous = @"CONTINUOUS";
UALocationEventUpdateType * const UALocationEventUpdateTypeSingle = @"SINGLE";
UALocationEventUpdateType * const UALocationEventUpdateTypeNone = @"NONE";

#pragma mark -
#pragma mark DesiredAccuracy/DistanceFilter Value

NSString * const UAAnalyticsValueNone = @"NONE";


#pragma mark -
#pragma mark Initialization

- (id)initWithLocationContext:(NSDictionary *)context {
    return [self initWithContext:context];
}

- (id)initWithLocation:(CLLocation *)location 
              provider:(id<UALocationProviderProtocol>)provider 
         andUpdateType:(UALocationEventUpdateType *)updateType {
    
    NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:10];
    [context setValue:provider.provider forKey:UALocationEventProviderKey];
    [context setValue:updateType forKey:UALocationEventUpdateTypeKey];
    [self populateDictionary:context withLocationValues:location];
    if (updateType == UALocationEventUpdateTypeChange) {
        [self setDefaultSignificantChangeDistanceAndAccuracyValuesInContext:context];
    }
    else {
        [self populateDictionary:context withLocationProviderValues:provider];
    }
    return [self initWithLocationContext:context];
}

- (id)initWithLocation:(CLLocation *)location
       locationManager:(CLLocationManager *)locationManager
         andUpdateType:(UALocationEventUpdateType *)updateType {
    
    NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:10];
    [context setValue:updateType forKey:UALocationEventUpdateTypeKey];
    [context setValue:UALocationServiceProviderUnknown forKey:UALocationEventProviderKey];
    [self populateDictionary:context withLocationValues:location];
    
    if (updateType == UALocationEventUpdateTypeChange) {
        [self setDefaultSignificantChangeDistanceAndAccuracyValuesInContext:context];
    } else {
        [self populateDictionary:context withLocationManagerValues:locationManager];
    }
    return [self initWithLocationContext:context];
}

- (void)populateDictionary:(NSMutableDictionary *)dictionary withLocationValues:(CLLocation *)location {
    [dictionary setValue:[self stringFromDoubleToSevenDigits:location.coordinate.latitude] forKey:UALocationEventLatitudeKey];
    [dictionary setValue:[self stringFromDoubleToSevenDigits:location.coordinate.longitude] forKey:UALocationEventLongitudeKey];
    [dictionary setValue:[self stringAsIntFromDouble:location.horizontalAccuracy] forKey:UALocationEventHorizontalAccuracyKey];
    [dictionary setValue:[self stringAsIntFromDouble:location.verticalAccuracy] forKey:UALocationEventVerticalAccuracyKey];
}

- (void)populateDictionary:(NSMutableDictionary *)dictionary withLocationManagerValues:(CLLocationManager *)locationManager {
    [dictionary setValue:[self stringAsIntFromDouble:locationManager.desiredAccuracy] forKey:UALocationEventDesiredAccuracyKey];
    // update_dist
    [dictionary setValue:[self stringAsIntFromDouble:locationManager.distanceFilter] forKey:UALocationEventDistanceFilterKey]; 
}

- (void)populateDictionary:(NSMutableDictionary *)dictionary withLocationProviderValues:(id<UALocationProviderProtocol>)locationProvider {
    [self populateDictionary:dictionary withLocationManagerValues:locationProvider.locationManager];
}

- (void)setDefaultSignificantChangeDistanceAndAccuracyValuesInContext:(NSMutableDictionary *)dictionary {
    [dictionary setValue:UAAnalyticsValueNone forKey:UALocationEventDistanceFilterKey];
    [dictionary setValue:UAAnalyticsValueNone forKey:UALocationEventDesiredAccuracyKey];
}


#pragma mark -
#pragma mark UAEvent Required overrides

- (NSString *)getType {
    return UALocationEventAnalyticsType;
}

- (void)gatherIndividualData:(NSDictionary *)context {
    [self.data addEntriesFromDictionary:context];
    [self addDataFromSessionForKey:UALocationEventSessionIDKey];
    
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state == UIApplicationStateActive){
        [self.data setValue:@"true" forKey:UALocationEventForegroundKey];
    } else {
        [self.data setValue:@"false" forKey:UALocationEventForegroundKey];
    }
}


- (NSString *)stringFromDoubleToSevenDigits:(double)doubleValue {
    return [NSString stringWithFormat:@"%.7f", doubleValue];
}

- (NSString *)stringAsIntFromDouble:(double)doubleValue {
    return [NSString stringWithFormat:@"%i", (int)doubleValue];
}

+ (UALocationEvent*)locationEventWithLocation:(CLLocation *)location 
                                     provider:(id<UALocationProviderProtocol>)provider 
                                andUpdateType:(UALocationEventUpdateType *)updateType {
    return [[UALocationEvent alloc] initWithLocation:location provider:provider andUpdateType:updateType];
}

+ (UALocationEvent *)locationEventWithLocation:(CLLocation *)loction 
                             locationManager:(CLLocationManager *)locationManager 
                                andUpdateType:(UALocationEventUpdateType*)updateType {
    return [[UALocationEvent alloc] initWithLocation:loction 
                                      locationManager:locationManager 
                                        andUpdateType:updateType];  
}



@end
