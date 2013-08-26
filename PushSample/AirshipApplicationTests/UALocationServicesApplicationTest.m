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

#import <CoreLocation/CoreLocation.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import <XCTest/XCTest.h>

#import "UALocationEvent.h"
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


@interface UALocationServicesApplicationTest : XCTestCase <UALocationServiceDelegate> {
  @private
    BOOL _locationReceived;
    BOOL _errorReceived;
    UALocationService *_locationService;
    NSDate *_timeout;
}

- (void)peformInvocationInBackground:(NSInvocation *)invocation;
@end


@implementation UALocationServicesApplicationTest

- (void)setUp{
    _locationReceived = NO;
    _errorReceived = YES;
    _locationService = nil;
    _timeout = nil;
}

- (void)tearDown {

    _locationService = nil;
    
    _timeout = nil;
}

#pragma mark -
#pragma mark Support Methods

- (BOOL)compareDoubleAsString:(NSString*)stringDouble toDouble:(double)doubleValue {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];

    NSNumber *numberFromString = [formatter numberFromString:stringDouble];
    NSNumber *numberFromDouble = [NSNumber numberWithDouble:doubleValue];

    return [numberFromDouble isEqualToNumber:numberFromString];
}

#pragma mark -
#pragma mark UAAnalytics UALocationEvent


- (void)testUALocationEventUpdateType {
    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
    UAStandardLocationProvider *standard = [[UAStandardLocationProvider alloc] init];
    UALocationService *service = [[UALocationService alloc] init];
    service.standardLocationProvider = standard;
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];

    // Setup object to get parsed out of method call
    __block __unsafe_unretained UALocationEvent *event = nil;

    // Capture the args passed to the mock in a block
    void (^eventBlock)(NSInvocation *) = ^(NSInvocation *invocation) 
    {
        [invocation getArgument:&event atIndex:2];
        NSLog(@"EVENT DATA %@", event.data);
    };
    [[[mockAnalytics stub] andDo:eventBlock] addEvent:[OCMArg any]];
    [service reportLocationToAnalytics:PDX fromProvider:standard];

    BOOL compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeContinuous;
    XCTAssertTrue(compare, @"UALocationEventUpdateType should be UAUALocationEventUpdateTypeContinuous for standardLocationProvider");
    compare = [event.data valueForKey:UALocationEventProviderKey] == UALocationServiceProviderGps;
    XCTAssertTrue(compare, @"UALocationServiceProvider should be UALocationServiceProviderGps");

    UASignificantChangeProvider *sigChange = [[UASignificantChangeProvider alloc] init];
    service.significantChangeProvider = sigChange;
    [service reportLocationToAnalytics:PDX fromProvider:sigChange];
    compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeChange;
    XCTAssertTrue(compare, @"UALocationEventUpdateType should be UAUALocationEventUpdateTypeChange");

    compare = [event.data valueForKey:UALocationEventProviderKey] == UALocationServiceProviderNetwork;
    XCTAssertTrue(compare, @"UALocationServiceProvider should be UALocationServiceProviderNetwork");

    UAStandardLocationProvider *single = [[UAStandardLocationProvider alloc] init];
    service.singleLocationProvider = single;
    [service reportLocationToAnalytics:PDX fromProvider:single];
    compare = [event.data valueForKey:UALocationEventUpdateTypeKey] == UALocationEventUpdateTypeSingle;
    XCTAssertTrue(compare, @"UALocationEventUpdateType should be UAUALocationEventUpdateTypeSingle");

    compare = [event.data valueForKey:UALocationEventProviderKey] == UALocationServiceProviderGps;
    XCTAssertTrue(compare, @"UALocationServiceProvider should be UALocationServiceProviderGps");

}

- (void)testUALocationServiceSendsLocationToAnalytics {
    UALocationService *service = [[UALocationService alloc] init];
    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    [[mockAnalytics expect] addEvent:[OCMArg any]];
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:nil];
    [service reportLocationToAnalytics:PDX fromProvider:standard];
    [mockAnalytics verify];
}

//// This is the dev analytics call that circumvents UALocation Services
- (void)testSendLocationWithLocationManger {
    _locationService = [[UALocationService alloc] initWithPurpose:@"TEST"];
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    
    __block __unsafe_unretained UALocationEvent *event = nil;

    // Capture the args passed to the mock in a block
    void (^eventBlock)(NSInvocation *) = ^(NSInvocation *invocation) 
    {
        [invocation getArgument:&event atIndex:2];
        NSLog(@"EVENT DATA %@", event.data);
    };
    [[[mockAnalytics stub] andDo:eventBlock] addEvent:[OCMArg any]];
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    UALocationEventUpdateType *type = UALocationEventUpdateTypeSingle;
    [_locationService reportLocation:pdx fromLocationManager:manager withUpdateType:type];
    NSDictionary *data = event.data;
    NSString *lat =  [data valueForKey:UALocationEventLatitudeKey];
    NSString *convertedLat = [NSString stringWithFormat:@"%.7f", pdx.coordinate.latitude];
    NSLog(@"LAT %@, CONVERTED LAT %@", lat, convertedLat);
    // Just do lightweight testing, heavy testing is done in the UALocationEvent class
    XCTAssertTrue([event isKindOfClass:[UALocationEvent class]]);
    XCTAssertTrue([lat isEqualToString:convertedLat]);
    UALocationEventUpdateType *typeInDate = (UALocationEventUpdateType*)[data valueForKey:UALocationEventUpdateTypeKey];
    XCTAssertTrue(type == typeInDate);
}

- (BOOL)serviceAcquiredLocation {
    _timeout = [[NSDate alloc] initWithTimeIntervalSinceNow:15];
    while (!_locationReceived) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        if ([_timeout timeIntervalSinceNow] < 0.0) {
            break;
        }
    }
    return _locationReceived;
}

// This test will not run automatically on a clean install
// as selecting OK for the location permission alert view
// tanks the run loop update
// TODO: figure out a way around this

- (void)testUALocationServiceDoesGetLocation {
    _locationService = [[UALocationService alloc] initWithPurpose:@"testing"];
    [UALocationService setAirshipLocationServiceEnabled:YES];
    _locationService.delegate = self;
    
    [_locationService startReportingStandardLocation];    
    XCTAssertTrue([self serviceAcquiredLocation], @"Location Service failed to acquire location");
}


#pragma mark -
#pragma mark Single Location Service Report Current location background

- (void)testReportCurrentLocationTimesOutWithError {
    __block BOOL shutdownCalled = NO;
    _locationService = [[UALocationService alloc] initWithPurpose:@"current location test"];
    _locationService.timeoutForSingleLocationService = 1;

    id mockLocationService = [OCMockObject partialMockForObject:_locationService];
    [[[mockLocationService stub] andDo:^(NSInvocation *invoc) { shutdownCalled = YES;}] stopSingleLocationWithError:OCMOCK_ANY];
    XCTAssertFalse(_locationService.singleLocationShutdownScheduled, @"singleLocationShutdownScheduled should be NO");

    [_locationService singleLocationDidUpdateToLocation:[UALocationTestUtils testLocationPDX] fromLocation:[UALocationTestUtils testLocationSFO]];
    XCTAssertTrue(_locationService.singleLocationShutdownScheduled, @"singleLocationShutdownScheduled should be YES");
    _timeout = [[NSDate alloc] initWithTimeInterval:3.0 sinceDate:[NSDate date]];

    while (!shutdownCalled) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        if ([_timeout timeIntervalSinceNow] < 0.0) {
            break;
        }
    }
    XCTAssertTrue(shutdownCalled, @"Location service should be shutdown when a location cannot be obtained within timeout limits");
}

- (void)testStopSingleLocationSetsShutdownScheduledFlag {
    _locationService.singleLocationShutdownScheduled = YES;
    [_locationService stopSingleLocation];
    XCTAssertFalse(_locationService.singleLocationShutdownScheduled, @"singleLocationServiceShutdownScheduled should be NO after stopSingleLocation");
}

- (void)testReportCurrentLocationShutsDownBackgroundTaskOnError {
    _locationService = [[UALocationService alloc] initWithPurpose:@"backgound shutdown test"];
    id mockLocationService = [OCMockObject partialMockForObject:_locationService];
    [[[mockLocationService stub] andReturnValue:@YES] isLocationServiceEnabledAndAuthorized];
    _locationService.singleLocationProvider = [UAStandardLocationProvider providerWithDelegate:_locationService];

    id mockProvider = [OCMockObject partialMockForObject:_locationService.singleLocationProvider];
    [[mockProvider stub] startReportingLocation];
    [_locationService reportCurrentLocation];
    XCTAssertFalse(_locationService.singleLocationBackgroundIdentifier == UIBackgroundTaskInvalid, @"LocationService background identifier should be valid");

    [_locationService.singleLocationProvider.delegate locationProvider:_locationService.singleLocationProvider 
                                                  withLocationManager:_locationService.singleLocationProvider.locationManager 
                                                     didFailWithError:[NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil]];
     XCTAssertTrue(_locationService.singleLocationBackgroundIdentifier == UIBackgroundTaskInvalid, @"LcoationService background identifier should be invalid");
    

}

#pragma mark -
#pragma mark Last Location and Date

- (void)testLastLocationAndDate {
    _locationService = [[UALocationService alloc] initWithPurpose:@"app_test"];
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    [_locationService reportLocationToAnalytics:pdx fromProvider:_locationService.standardLocationProvider];
    XCTAssertEqualObjects(pdx, _locationService.lastReportedLocation);
    NSTimeInterval smallAmountOfTime = [_locationService.dateOfLastLocation timeIntervalSinceNow];
    XCTAssertEqualWithAccuracy(smallAmountOfTime, 0.1, 0.5);
}

#pragma mark -
#pragma mark UALocationService Delegate methods

- (void)locationService:(UALocationService*)service didFailWithError:(NSError*)error{
    NSLog(@"Location error received %@", error);
    _errorReceived = YES;
}
- (void)locationService:(UALocationService*)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
    NSLog(@"Authorization status changed to %u",status);
}
- (void)locationService:(UALocationService*)service didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation{
    NSLog(@"Location received");
    _locationReceived = YES;
}
                                                                            
- (void)peformInvocationInBackground:(NSInvocation *)invocation {
    @autoreleasepool {
        [invocation invoke];
    }
}

- (void)testSignificantChangeNotifiesDelegate {
    _locationService = [[UALocationService alloc] initWithPurpose:@"Test"];
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];

    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    [[mockDelegate expect] locationService:_locationService didUpdateToLocation:pdx fromLocation:sfo];
    UASignificantChangeProvider *sigChange = [UASignificantChangeProvider providerWithDelegate:_locationService];
    _locationService.significantChangeProvider = sigChange;
    _locationService.delegate = mockDelegate;
    [sigChange.delegate locationProvider:sigChange withLocationManager:sigChange.locationManager didUpdateLocation:pdx fromLocation:sfo];
    [mockDelegate verify];
}

@end
