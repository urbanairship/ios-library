//
//  PushSampleLib - UALocationEventApplicationTests.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UALocationService.h"
#import "UALocationService+Internal.h"
#import "UALocationEvent.h"
#import "UALocationCommonValues.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UALocationTestUtils.h"
#import "UAStandardLocationProvider.h"
#import <SenTestingKit/SenTestingKit.h>


@interface UALocationEventApplicationTests : SenTestCase {
    CLLocation *location;
}
@end
// TODO: Check on whether the session_id is actually going up if you take it out of the 
// payload

/**
 *  The context includes all the data necessary for a 
 *  location event. These are:
 *  
 *  "session_id": "UUID"
 *  "lat" : "31.3847" (required, DDD.dddd... string double)
 *  "long": "32.3847" (required, DDD.dddd... string double)
 *  "requested_accuracy": "10.0,100.0,NONE" (required, requested accuracy in meters as a string double)
 *  "update_type": "CHANGE, CONTINUOUS, SINGLE, NONE" (required - string enum)
 *  "provider": "GPS, NETWORK, PASSIVE, UNKNOWN" (required - string enum)
 *  "update_dist": "10.0,100.0,NONE" (required - string double distance in meters, or NONE if not available applicable)
 *  "h_accuracy": "10.0, NONE" (required, string double - actual horizontal accuracy in meters, or NONE if not available)
 *  "v_accuracy": "10.0, NONE" (required, string double - actual vertical accuracy in meters, or NONE if not available)
 *  "foreground": "true" (required, string boolean)
 */

@implementation UALocationEventApplicationTests

- (void)setUp {
    location = [[UALocationTestUtils testLocationPDX] retain];
}

- (void)tearDown {
    RELEASE(location);
}

- (void)testInitWithLocationManager {
    CLLocationManager *locationManager = [[[CLLocationManager alloc] init] autorelease];
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:location 
                                                        locationManager:locationManager 
                                                          andUpdateType:locationEventUpdateTypeSingle];
    NSDictionary *data = event.data;
    
    // 0.000001 equals sub meter accuracy at the equator. 
    STAssertEqualsWithAccuracy(location.coordinate.latitude, [[data valueForKey:locationEventLatitudeKey] doubleValue], 0.000001, nil);
    STAssertEqualsWithAccuracy(location.coordinate.longitude, [[data valueForKey:locationEventLongitudeKey] doubleValue],0.000001 ,nil);
    STAssertEquals(location.horizontalAccuracy, [[data valueForKey:locationEventHorizontalAccuracyKey] doubleValue],nil);
    STAssertEquals(location.verticalAccuracy, [[data valueForKey:locationEventVerticalAccuracyKey] doubleValue],nil);
    STAssertEquals(locationManager.desiredAccuracy, [[data valueForKey:locationEventDesiredAccuracyKey] doubleValue],nil);
    // update_type
    STAssertEquals(locationManager.distanceFilter, [[data valueForKey:locationEventDistanceFilterKey] doubleValue] ,nil);
    STAssertTrue((locationEventUpdateTypeSingle == [data valueForKey:locationEventUpdateTypeKey]) ,nil);
    STAssertTrue((UAAnalyticsTrueValue == [data valueForKey:locationEventForegroundKey]), nil);
    STAssertTrue((locationServiceProviderUnknown == [data valueForKey:locationEventProviderKey]), nil);

}


- (void)testInitWithProvider {
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:nil];
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:location provider:standard andUpdateType:locationEventUpdateTypeContinuous];
    NSDictionary *data = event.data;
    STAssertEqualsWithAccuracy(location.coordinate.latitude, [[data valueForKey:locationEventLatitudeKey] doubleValue], 0.000001, nil);
    STAssertEqualsWithAccuracy(location.coordinate.longitude, [[data valueForKey:locationEventLongitudeKey] doubleValue],0.000001, nil);
    STAssertEquals(location.horizontalAccuracy, [[data valueForKey:locationEventHorizontalAccuracyKey] doubleValue], nil);
    STAssertEquals(location.verticalAccuracy, [[data valueForKey:locationEventVerticalAccuracyKey] doubleValue], nil);
    //TODO: add tests after the UALocationService pass through is completed
    STAssertEquals(standard.desiredAccuracy, [[data valueForKey:locationEventDesiredAccuracyKey] doubleValue],nil);
    STAssertEquals(standard.distanceFilter, [[data valueForKey:locationEventDistanceFilterKey] doubleValue] ,nil);
    STAssertTrue((locationEventUpdateTypeContinuous == [data valueForKey:locationEventUpdateTypeKey]) ,nil);
    STAssertTrue((UAAnalyticsTrueValue == [data valueForKey:locationEventForegroundKey]), nil);
    STAssertTrue((locationServiceProviderGps == [data valueForKey:locationEventProviderKey]), nil);
    
}


@end
