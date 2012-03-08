//
//  PushSampleLib - UALocationEventApplicationTests.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UALocationService.h"
#import "UALocationService_Private.h"
#import "UALocationEvent.h"
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
    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:PDX 
                                                        locationManager:locationManager 
                                                          andUpdateType:UALocationEventUpdateTypeSINGLE];
    NSDictionary *data = event.data;
    
    // 0.000001 equals sub meter accuracy at the equator. 
    STAssertEqualsWithAccuracy(PDX.coordinate.latitude, [[data valueForKey:UALocationEventLatitudeKey] doubleValue], 0.000001, nil);
    STAssertEqualsWithAccuracy(PDX.coordinate.longitude, [[data valueForKey:UALocationEventLongitudeKey] doubleValue],0.000001 ,nil);
    STAssertEquals(PDX.horizontalAccuracy, [[data valueForKey:UALocationEventHorizontalAccuracyKey] doubleValue],nil);
    STAssertEquals(PDX.verticalAccuracy, [[data valueForKey:UALocationEventVerticalAccuracyKey] doubleValue],nil);
    STAssertEquals(locationManager.desiredAccuracy, [[data valueForKey:UALocationEventDesiredAccuracyKey] doubleValue],nil);
    // update_type
    STAssertEquals(locationManager.distanceFilter, [[data valueForKey:UALocationEventDistanceFilterKey] doubleValue] ,nil);
    STAssertTrue([UALocationEventUpdateTypeSINGLE isEqualToString:[data valueForKey:UALocationEventUpdateTypeKey]] ,nil);
    STAssertTrue([UAAnalyticsTrueValue isEqualToString:[data valueForKey:UALocationEventForegroundKey]], nil);
    // SETUP PROVIDER
}


@end
