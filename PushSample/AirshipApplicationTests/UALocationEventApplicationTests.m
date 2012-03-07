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

- (void)testUALocationEventInit {
    // Basic init
    UALocationEvent *event = [[[UALocationEvent alloc] initWithLocationContext:[NSDictionary dictionaryWithObject:@"STUFF" forKey:@"CATS"]] autorelease];
    STAssertEquals(@"STUFF", [event.data valueForKey:@"CATS"], nil);
    /////
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    CLLocationAccuracy locationAccuracy =  42.0;
    CLLocationDistance distanceFilter = 7.0;
    event = [[[UALocationEvent alloc] initWithLocation:pdx 
                                             provider:UALocationServiceProviderGPS 
                                      desiredAccuracy:locationAccuracy 
                                    andDistanceFilter:distanceFilter] autorelease];
    STAssertEquals(pdx.coordinate.latitude, [[event.data valueForKey:UALocationEventLatitudeKey] doubleValue], nil);
    STAssertEquals(pdx.coordinate.longitude, [[event.data valueForKey:UALocationEventLongitudeKey] doubleValue], nil);
    STAssertEquals(pdx.horizontalAccuracy, [[event.data valueForKey:UALocationEventHorizontalAccuracyKey] doubleValue], nil);
    STAssertEquals(pdx.verticalAccuracy, [[event.data valueForKey:UALocationEventVerticalAccuracyKey] doubleValue], nil);
    STAssertEquals(UALocationServiceProviderGPS, (UALocationServiceProviderType*)[event.data valueForKey:UALocationEventProviderKey], nil);
    STAssertEquals(locationAccuracy, [[event.data valueForKey:UALocationEventDesiredAccuracyKey] doubleValue], nil);
    STAssertEquals(distanceFilter, [[event.data valueForKey:UALocationEventDistanceFilterKey] doubleValue], nil);
    STAssertEquals(YES, [[event.data valueForKey:UALocationEventForegroundKey] boolValue], nil);
    NSDictionary *session = [UAirship shared].analytics.session;
    STAssertEquals([session valueForKey:UALocationEventSessionIDKey], [event.data valueForKey:UALocationEventSessionIDKey], nil);
}


@end
