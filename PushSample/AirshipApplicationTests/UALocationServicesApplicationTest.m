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
    BOOL errorRecieved;
    UALocationService *locationService;
    NSDate *timeout;
}

- (void)peformInvocationInBackground:(NSInvocation*)invocation;
@end


@implementation UALocationServicesApplicationTest

- (void)setUp{
    locationRecieved = NO;
    errorRecieved = YES;
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
    compare = [event.data valueForKey:UALocationEventProviderKey] == UALocationServiceProviderGps;
    STAssertTrue(compare, @"UALocationServiceProvider should be UALocationServiceProviderGps");
    UASignificantChangeProvider* sigChange = [[[UASignificantChangeProvider alloc] init] autorelease];
    service.significantChangeProvider = sigChange;
    [service reportLocationToAnalytics:PDX fromProvider:sigChange];
    compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeChange;
    STAssertTrue(compare, @"UALocationEventUpdateType should be UAUALocationEventUpdateTypeChange");
    compare = [event.data valueForKey:UALocationEventProviderKey] == UALocationServiceProviderNetwork;
    STAssertTrue(compare, @"UALocationServiceProvider should be UALocationServiceProviderNetwork");
    UAStandardLocationProvider *single = [[[UAStandardLocationProvider alloc] init] autorelease];
    service.singleLocationProvider = single;
    [service reportLocationToAnalytics:PDX fromProvider:single];
    compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeSingle;
    STAssertTrue(compare, @"UALocationEventUpdateType should be UAUALocationEventUpdateTypeSingle");
    compare = [event.data valueForKey:UALocationEventProviderKey] == UALocationServiceProviderGps;
    STAssertTrue(compare, @"UALocationServiceProvider should be UALocationServiceProviderGps");

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

- (BOOL)serviceAcquiredLocation {
    timeout = [[NSDate alloc] initWithTimeIntervalSinceNow:15];
    while (!locationRecieved) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        if ([timeout timeIntervalSinceNow] < 0.0) {
            break;
        }
    }
    return locationRecieved;
}

// This test will not run automatically on a clean install
// as selecting OK for the location permission alert view
// tanks the run loop update
// TODO: figure out a way around this

//- (void)testUALocationServiceDoesGetLocation {
//    locationService = [[UALocationService alloc] initWithPurpose:@"testing"];
//    [UALocationService setAirshipLocationServiceEnabled:YES];
//    locationService.delegate = self;
//    [locationService startReportingStandardLocation];    
//    STAssertTrue([self serviceAcquiredLocation], @"Location Service failed to acquire location");
//}


#pragma mark -
#pragma mark Single Location Service Report Current location background

- (void)testReportCurrentLocationTimesOutWithError {
    __block BOOL shutdownCalled = NO;
    locationService = [[UALocationService alloc] initWithPurpose:@"current location test"];
    locationService.timeoutForSingleLocationService = 1;
    id mockLocationService = [OCMockObject partialMockForObject:locationService];
    [[[mockLocationService stub] andDo:^(NSInvocation *invoc) { shutdownCalled = YES;}] stopSingleLocationWithError:OCMOCK_ANY];
    STAssertFalse(locationService.singleLocationShutdownScheduled, @"singleLocationShutdownScheduled should be NO");
    [locationService singleLocationDidUpdateToLocation:[UALocationTestUtils testLocationPDX] fromLocation:[UALocationTestUtils testLocationSFO]];
    STAssertTrue(locationService.singleLocationShutdownScheduled, @"singleLocationShutdownScheduled should be YES");
    timeout = [[NSDate alloc] initWithTimeInterval:3.0 sinceDate:[NSDate date]];
    while (!shutdownCalled) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        if ([timeout timeIntervalSinceNow] < 0.0) {
            break;
        }
    }
    STAssertTrue(shutdownCalled, @"Location service should be shutdown when a location cannot be obtained within timeout limits");
}

- (void)testStopSingleLocationSetsShutdownScheduledFlag {
    locationService.singleLocationShutdownScheduled = YES;
    [locationService stopSingleLocation];
    STAssertFalse(locationService.singleLocationShutdownScheduled, @"singleLocationServiceShutdownScheduled should be NO after stopSingleLocation");
}

- (void)testReportCurrentLocationShutsDownBackgroundTaskOnError {
    BOOL yes = YES;
    locationService = [[UALocationService alloc] initWithPurpose:@"backgound shutdown test"];
    id mockLocationService = [OCMockObject partialMockForObject:locationService];
    [[[mockLocationService stub] andReturnValue:OCMOCK_VALUE(yes)] isLocationServiceEnabledAndAuthorized];
    locationService.singleLocationProvider = [UAStandardLocationProvider providerWithDelegate:locationService];
    id mockProvider = [OCMockObject partialMockForObject:locationService.singleLocationProvider];
    [[mockProvider stub] startReportingLocation];
    [locationService reportCurrentLocation];
    STAssertFalse(locationService.singleLocationBackgroundIdentifier == UIBackgroundTaskInvalid, @"LocationService background identifier should be valid");
    [locationService.singleLocationProvider.delegate locationProvider:locationService.singleLocationProvider 
                                                  withLocationManager:locationService.singleLocationProvider.locationManager 
                                                     didFailWithError:[NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil]];
     STAssertTrue(locationService.singleLocationBackgroundIdentifier == UIBackgroundTaskInvalid, @"LcoationService background identifier should be invalid");
    

}

#pragma mark -
#pragma mark Last Location and Date

- (void)testLastLocationAndDate {
    locationService = [[UALocationService alloc] initWithPurpose:@"app_test"];
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    [locationService reportLocationToAnalytics:pdx fromProvider:locationService.standardLocationProvider];
    STAssertEqualObjects(pdx, locationService.lastReportedLocation, nil);
    NSTimeInterval smallAmountOfTime = [locationService.dateOfLastLocation timeIntervalSinceNow];
    STAssertEqualsWithAccuracy(smallAmountOfTime, 0.1, 0.5, nil);
}

#pragma mark -
#pragma mark UALocationService Delegate methods

- (void)locationService:(UALocationService*)service didFailWithError:(NSError*)error{
    NSLog(@"Location error received %@", error);
    errorRecieved = YES;
}
- (void)locationService:(UALocationService*)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
    NSLog(@"Authorization status changed to %u",status);
}
- (void)locationService:(UALocationService*)service didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation{
    NSLog(@"Location received");
    locationRecieved = YES;
}

- (void)testSendEventOnlyCallsOnMainThread {
    UALocationService *service = [[UALocationService alloc] initWithPurpose:@"Test"];
    __block BOOL onMainThread = NO;
    void (^argBlock)(NSInvocation*) = ^(NSInvocation* invocation) {
        onMainThread = [[NSThread currentThread] isMainThread];
    };
    CLLocation *location = [UALocationTestUtils testLocationPDX];
    UAAnalytics *analytics = [[UAirship shared] analytics];
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[[mockAnalytics stub] andDo:argBlock] addEvent:OCMOCK_ANY];
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:[service methodSignatureForSelector:@selector(reportLocationToAnalytics:fromProvider:)]];
    [invocation setTarget:service];
    [invocation setSelector:@selector(reportLocationToAnalytics:fromProvider:)];
    [invocation setArgument:&location atIndex:2];
    UAStandardLocationProvider *provider = locationService.standardLocationProvider;
    [invocation setArgument:&provider atIndex:3];
    [invocation retainArguments];
    [invocation invoke];
    STAssertTrue(onMainThread, nil);
    onMainThread = NO;
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(peformInvocationInBackground:) object:invocation];
    [thread start];
    do {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    } while(![thread isFinished]);
    STAssertTrue(onMainThread, nil);
    [thread release];
    [service autorelease];
}
                                                                            
- (void)peformInvocationInBackground:(NSInvocation*)invocation {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [invocation invoke];
    [pool drain];
}

- (void)testSignificantChangeNotifiesDelegate {
    locationService = [[UALocationService alloc] initWithPurpose:@"Test"];
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    [[mockDelegate expect] locationService:locationService didUpdateToLocation:pdx fromLocation:sfo];
    UASignificantChangeProvider *sigChange = [UASignificantChangeProvider providerWithDelegate:locationService];
    locationService.significantChangeProvider = sigChange;
    locationService.delegate = mockDelegate;
    [sigChange.delegate locationProvider:sigChange withLocationManager:sigChange.locationManager didUpdateLocation:pdx fromLocation:sfo];
    [mockDelegate verify];
}

@end
