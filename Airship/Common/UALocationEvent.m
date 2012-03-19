/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
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

UALocationEventAnalyticsKey * const locationEventSessionIDKey = @"session_id";
UALocationEventAnalyticsKey * const locationEventForegroundKey = @"foreground";
UALocationEventAnalyticsKey * const locationEventLatitudeKey = @"lat";
UALocationEventAnalyticsKey * const locationEventLongitudeKey = @"long";
UALocationEventAnalyticsKey * const locationEventDesiredAccuracyKey = @"requested_accuracy";
UALocationEventAnalyticsKey * const locationEventUpdateTypeKey = @"update_type";
UALocationEventAnalyticsKey * const locationEventProviderKey = @"provider";
UALocationEventAnalyticsKey * const locationEventDistanceFilterKey = @"update_dist";
UALocationEventAnalyticsKey * const locationEventHorizontalAccuracyKey = @"h_accuracy";
UALocationEventAnalyticsKey * const locationEventVerticalAccuracyKey = @"v_accuracy";

#pragma mark -
#pragma mark UALocationEventUpdateType

UALocationEventUpdateType * const locationEventAnalyticsType = @"location";
UALocationEventUpdateType * const locationEventUpdateTypeChange = @"CHANGE";
UALocationEventUpdateType * const locationEventUpdateTypeContinuous = @"CONTINUOUS";
UALocationEventUpdateType * const locationEventUpdateTypeSingle = @"SINGLE";
UALocationEventUpdateType * const locationEventUpdateTypeNone = @"NONE";


#pragma mark -
#pragma mark Initialization


- (id)initWithLocationContext:(NSDictionary*)context {
    return [self initWithContext:context];
}

- (id)initWithLocation:(CLLocation*)location 
              provider:(id<UALocationProviderProtocol>)provider 
         andUpdateType:(UALocationEventUpdateType*)updateType {
    NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:10];
    [context setValue:provider.provider forKey:locationEventProviderKey];
    [context setValue:updateType forKey:locationEventUpdateTypeKey];
    [self populateDictionary:context withLocationValues:location];
    [self populateDictionary:context withLocationProviderValues:provider];
    return [self initWithLocationContext:context];
}

- (id)initWithLocation:(CLLocation*)location 
       locationManager:(CLLocationManager*)locationManager 
       andUpdateType:(UALocationEventUpdateType*)updateType {
    NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:10];
    [context setValue:updateType forKey:locationEventUpdateTypeKey];
    [context setValue:locationServiceProviderUnknown forKey:locationEventProviderKey];
    [self populateDictionary:context withLocationValues:location];
    [self populateDictionary:context withLocationManagerValues:locationManager];
    return [self initWithLocationContext:context];
}

- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationValues:(CLLocation*)location {
    [dictionary setValue:[self stringFromDoubleToSevenDigits:location.coordinate.latitude] forKey:locationEventLatitudeKey];
    [dictionary setValue:[self stringFromDoubleToSevenDigits:location.coordinate.longitude] forKey:locationEventLongitudeKey];
    [dictionary setValue:[self stringFromDoubleToSevenDigits:location.horizontalAccuracy] forKey:locationEventHorizontalAccuracyKey];
    [dictionary setValue:[self stringFromDoubleToSevenDigits:location.verticalAccuracy] forKey:locationEventVerticalAccuracyKey];
}

- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationManagerValues:(CLLocationManager *)locationManager {
    [dictionary setValue:[self stringFromDoubleToSevenDigits:locationManager.desiredAccuracy] forKey:locationEventDesiredAccuracyKey];
    // update_dist
    [dictionary setValue:[self stringFromDoubleToSevenDigits:locationManager.distanceFilter] forKey:locationEventDistanceFilterKey]; 
}

- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationProviderValues:(id<UALocationProviderProtocol>)locationProvider {
    [self populateDictionary:dictionary withLocationManagerValues:locationProvider.locationManager];
}


#pragma mark -
#pragma mark UAEvent Required overrides

- (NSString*)getType {
    return locationEventAnalyticsType;
}

- (void)gatherIndividualData:(NSDictionary *)context {
    [data addEntriesFromDictionary:context];
    [self addDataFromSessionForKey:locationEventSessionIDKey];
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state == UIApplicationStateActive){
        [data setValue:UAAnalyticsTrueValue forKey:locationEventForegroundKey];
    }
    else [data setValue:UAAnalyticsFalseValue forKey:locationEventForegroundKey];
}


- (NSString*)stringFromDoubleToSevenDigits:(double)doubleValue {
    return [NSString stringWithFormat:@"%.7f", doubleValue];
}

+ (UALocationEvent*)locationEventWithLocation:(CLLocation*)location 
                                     provider:(id<UALocationProviderProtocol>)provider 
                                andUpdateType:(UALocationEventUpdateType*)updateType {
    return [[[UALocationEvent alloc] initWithLocation:location provider:provider andUpdateType:updateType] autorelease];
}

+ (UALocationEvent*)locationEventWithLocation:(CLLocation*)loction 
                             locationManager:(CLLocationManager*)locationManager 
                                andUpdateType:(UALocationEventUpdateType*)updateType {
    return [[[UALocationEvent alloc] initWithLocation:loction 
                                      locationManager:locationManager 
                                        andUpdateType:updateType] autorelease];  
}



@end
