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
#import <SenTestingKit/SenTestingKit.h>
#import "UALocationEvent.h"
#import "UALocationService.h"
#import "UALocationService+Internal.h"
#import "UALocationCommonValues.h"
#import "UABaseLocationProvider.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UALocationTestUtils.h"


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


- (void)testUALocationEventUpdateType {
    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] init] autorelease];
    UALocationService *service = [[[UALocationService alloc] init] autorelease];
    service.standardLocationProvider = standard;
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    // Setup object to get parsed out of method call
    __block UALocationEvent* event;
    // Capture the args passed to the mock in a block
    void (^eventBlock)(NSInvocation *) = ^(NSInvocation *invocation) 
    {
        [invocation getArgument:&event atIndex:2];
        NSLog(@"EVENT DATA %@", event.data);
    };
    [[[mockAnalytics stub] andDo:eventBlock] addEvent:[OCMArg any]];
    [service reportLocationToAnalytics:PDX fromProvider:standard];
    BOOL compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeContinuous;
    STAssertTrue(compare, @"UALocationEventUpdateType should be UAUALocationEventUpdateTypeContinuous for standardLocationProvider");
    UASignificantChangeProvider* sigChange = [[[UASignificantChangeProvider alloc] init] autorelease];
    service.significantChangeProvider = sigChange;
    [service reportLocationToAnalytics:PDX fromProvider:sigChange];
    compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeChange;
    STAssertTrue(compare, @"UALocationEventUpdateType should be UAUALocationEventUpdateTypeChange");
    UAStandardLocationProvider *single = [[[UAStandardLocationProvider alloc] init] autorelease];
    service.singleLocationProvider = single;
    [service reportLocationToAnalytics:PDX fromProvider:single];
    compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeSingle;
    STAssertTrue(compare, @"UALocationEventUpdateType should be UAUALocationEventUpdateTypeSingle");
    
}

- (void)testUALocationServiceSendsLocationToAnalytics {
    UALocationService *service = [[[UALocationService alloc] init] autorelease];
    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    [[mockAnalytics expect] addEvent:[OCMArg any]];
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:nil];
    [service reportLocationToAnalytics:PDX fromProvider:standard];
    [mockAnalytics verify];
}

//// This is the dev analytics call that circumvents UALocation Services
- (void)testSendLocationWithLocationManger {
    locationService = [[UALocationService alloc] initWithPurpose:@"TEST"];
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    __block UALocationEvent* event = nil;
    // Capture the args passed to the mock in a block
    void (^eventBlock)(NSInvocation *) = ^(NSInvocation *invocation) 
    {
        [invocation getArgument:&event atIndex:2];
        NSLog(@"EVENT DATA %@", event.data);
    };
    [[[mockAnalytics stub] andDo:eventBlock] addEvent:[OCMArg any]];
    CLLocationManager *manager = [[[CLLocationManager alloc] init] autorelease];
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    UALocationEventUpdateType *type = UALocationEventUpdateTypeSingle;
    [locationService reportLocation:pdx fromLocationManager:manager withUpdateType:type];
    NSDictionary *data = event.data;
    NSString* lat =  [data valueForKey:UALocationEventLatitudeKey];
    NSString* convertedLat = [NSString stringWithFormat:@"%.7f", pdx.coordinate.latitude];
    NSLog(@"LAT %@, CONVERTED LAT %@", lat, convertedLat);
    // Just do lightweight testing, heavy testing is done in the UALocationEvent class
    STAssertTrue([event isKindOfClass:[UALocationEvent class]],nil);
    STAssertTrue([lat isEqualToString:convertedLat], nil);
    UALocationEventUpdateType *typeInDate = (UALocationEventUpdateType*)[data valueForKey:UALocationEventUpdateTypeKey];
    STAssertTrue(type == typeInDate, nil);
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

- (void)locationService:(UALocationService*)service didFailWithError:(NSError*)error{
    STFail(@"Location service failed");    
}
- (void)locationService:(UALocationService*)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
    NSLog(@"Authorization status changed to %u",status);
}
- (void)locationService:(UALocationService*)service didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation{
    NSLog(@"Location received");
    locationRecieved = YES;
}


@end
