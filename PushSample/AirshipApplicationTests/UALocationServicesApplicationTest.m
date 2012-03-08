//
//  AirshipApplicationTests.m
//  AirshipApplicationTests
//
//  Created by Matt Hooge on 1/16/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UALocationEvent.h"
#import "UALocationService.h"
#import "UALocationService_Private.h"
#import "UABaseLocationProvider.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UALocationTestUtils.h"
#import <SenTestingKit/SenTestingKit.h>

@interface UALocationServicesApplicationTest : SenTestCase <UALocationServiceDelegate> {
    BOOL locationRecieved;
    UALocationService *locationService;
    NSDate *timeout;
}
- (BOOL)serviceAcquiredLocation;
@end


@implementation UALocationServicesApplicationTest

- (void)setUp{
    locationRecieved = NO;
    locationService = nil;
    timeout = nil;
}

- (void)tearDown {
    RELEASE(locationService);
    RELEASE(timeout);
}

//#pragma mark -
//#pragma mark Support Methods


- (BOOL)compareDoubleAsString:(NSString*)stringDouble toDouble:(double)doubleValue {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *numberFromString = [formatter numberFromString:stringDouble];
    NSNumber *numberFromDouble = [NSNumber numberWithDouble:doubleValue];
    [formatter release];
    return [numberFromDouble isEqualToNumber:numberFromString];
}

#pragma mark -
#pragma mark NSUserDefaults UALocationServicePreferences
- (void)testUserDefaults {
    NSDictionary* locationDefaults = [[NSUserDefaults standardUserDefaults] dictionaryForKey:UALocationServicePreferences];
    STAssertNotNil(locationDefaults, @"Location defaults should exist");
}

#pragma mark -
#pragma mark UAAnalytics UALocationEvent

/**
 The context includes all the data necessary for a 
 location event. These are:
 
 "lat" : "31.3847" (required, DDD.dddd... string double)
 "long": "32.3847" (required, DDD.dddd... string double)
 "requested_accuracy": "10.0,100.0,NONE" (required, requested accuracy in meters as a string double)
 "update_type": "CHANGE, CONTINUOUS, SINGLE, NONE" (required - string enum)
 "provider": "GPS, NETWORK, PASSIVE, UNKNOWN" (required - string enum)
 "update_dist": "10.0,100.0,NONE" (required - string double distance in meters, or NONE if not available applicable)
 "h_accuracy": "10.0, NONE" (required, string double - actual horizontal accuracy in meters, or NONE if not available)
 "v_accuracy": "10.0, NONE" (required, string double - actual vertical accuracy in meters, or NONE if not available)
 
 It should be sufficient to test one location provider, as the only methods used are required protocol methods.
 */
//- (void)testUALocationEvent {
//    locationService = [[UALocationService alloc] init];
//    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:nil];
//    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
//    UALocationEvent *event = [locationService createLocationEventWithLocation:pdx andProvider:standard];
//    STAssertTrue([event isKindOfClass:[UALocationEvent class]], nil);
//    NSDictionary *eventDictionary = event.data;    
//    STAssertEquals(pdx.coordinate.latitude, [[eventDictionary valueForKey:UALocationEventLatitudeKey] doubleValue], nil);
//    STAssertEquals(pdx.coordinate.longitude, [[eventDictionary valueForKey:UALocationEventLongitudeKey] doubleValue], nil);
//    STAssertEquals(standard.locationManager.desiredAccuracy, [[eventDictionary valueForKey:UALocationEventDesiredAccuracyKey] doubleValue], nil);
//    STAssertEquals(standard.locationManager.distanceFilter, [[eventDictionary valueForKey:UALocationEventDistanceFilterKey] doubleValue], nil);
//    STAssertEquals(standard.provider, (UALocationServiceProviderType*)[eventDictionary valueForKey:UALocationEventProviderKey], nil);
//    STAssertEquals(pdx.horizontalAccuracy, [[eventDictionary valueForKey:UALocationEventHorizontalAccuracyKey] doubleValue], nil);
//    STAssertEquals(pdx.verticalAccuracy, [[eventDictionary valueForKey:UALocationEventVerticalAccuracyKey] doubleValue], nil);
//}

//- (void)testUALocationEventUpdateType {
//    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
//    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] init] autorelease];
//    UALocationService *service = [[[UALocationService alloc] init] autorelease];
//    service.standardLocationProvider = standard;
//    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
//    // Setup object to get parsed out of method call
//    __block UALocationEvent* event;
//    // Capture the args passed to the mock in a block
//    void (^eventBlock)(NSInvocation *) = ^(NSInvocation *invocation) 
//    {
//        [invocation getArgument:&event atIndex:2];
//        NSLog(@"EVENT DATA %@", event.data);
//    };
//    [[[mockAnalytics stub] andDo:eventBlock] addEvent:[OCMArg any]];
//    [service sendLocationToAnalytics:PDX fromProvider:standard];
//    BOOL compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeCONTINUOUS;
//    STAssertTrue(compare, @"UALocationEventUpdateType should be UALocationEventUpdateTypeCONTINUOUS for standardLocationProvider");
//    UASignificantChangeProvider* sigChange = [[[UASignificantChangeProvider alloc] init] autorelease];
//    service.significantChangeProvider = sigChange;
//    [service sendLocationToAnalytics:PDX fromProvider:sigChange];
//    compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeCHANGE;
//    STAssertTrue(compare, @"UALocationEventUpdateType should be UALocationEventUpdateTypeCHANGE");
//    service.singleLocationProvider = standard;
//    [service sendLocationToAnalytics:PDX fromProvider:standard];
//    compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeSINGLE;
//    STAssertTrue(compare, @"UALocationEventUpdateType should be UALocationEventUpdateTypeSINGLE");
//    
//}

- (void)testUALocationServiceSendsLocationToAnalytics {
    UALocationService *service = [[[UALocationService alloc] init] autorelease];
    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    [[mockAnalytics expect] addEvent:[OCMArg any]];
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:nil];
    [service sendLocationToAnalytics:PDX fromProvider:standard];
    [mockAnalytics verify];
}

// This test will not run automatically on a clean install
// as selecting OK for the location permission alert view
// tanks the run loop update
// TODO: figure out a way around this

//- (void)testUALocationServiceDoesGetLocation {
//    locationService = [[UALocationService alloc] initWithPurpose:@"testing"];
//    locationService.locationServiceAllowed = YES;
//    locationService.locationServiceEnabled = YES;
//    locationService.delegate = self;
//    [locationService startReportingLocation];    
//    STAssertTrue([self serviceAcquiredLocation], @"Location Service failed to acquire location");
//}

- (BOOL)serviceAcquiredLocation {
    timeout = [[NSDate alloc] initWithTimeIntervalSinceNow:15];
    while (!locationRecieved) {
        [[NSRunLoop currentRunLoop] runMode:NSRunLoopCommonModes beforeDate:timeout];
        if ([timeout timeIntervalSinceNow] < 0.0) {
            break;
        }
    }
    return locationRecieved;
}

#pragma mark -
#pragma mark UALocationService Delegate methods

- (void)UALocationService:(UALocationService*)service didFailWithError:(NSError*)error{
    STFail(@"Location service failed");    
}
- (void)UALocationService:(UALocationService*)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
    NSLog(@"Authorization status changed to %u",status);
}
- (void)UALocationService:(UALocationService*)service didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation{
    NSLog(@"Location received");
    locationRecieved = YES;
}


@end
