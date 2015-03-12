/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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
    __block UALocationEvent *event = nil;

    // Capture the args passed to the mock in a block
    void (^eventBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        __unsafe_unretained UALocationEvent *unsafeEvent = nil;
        [invocation getArgument:&unsafeEvent atIndex:2];
        event = unsafeEvent;
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

    [mockAnalytics stopMocking];
}

- (void)testUALocationServiceSendsLocationToAnalytics {
    UALocationService *service = [[UALocationService alloc] init];
    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    [[mockAnalytics expect] addEvent:[OCMArg any]];
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:nil];
    [service reportLocationToAnalytics:PDX fromProvider:standard];
    [mockAnalytics verify];
    [mockAnalytics stopMocking];
}

#pragma mark -
#pragma mark Single Location Service Report Current location background

- (void)testReportCurrentLocationTimesOutWithError {
    __block BOOL shutdownCalled = NO;
    _locationService = [[UALocationService alloc] init];
    _locationService.timeoutForSingleLocationService = 1;

    id mockLocationService = [OCMockObject partialMockForObject:_locationService];
    [[[mockLocationService stub] andDo:^(NSInvocation *invoc) {
            shutdownCalled = YES;
        }] stopSingleLocationWithError:OCMOCK_ANY];
    XCTAssertFalse(_locationService.singleLocationShutdownScheduled, @"singleLocationShutdownScheduled should be NO");

    [_locationService singleLocationDidUpdateLocations:@[[UALocationTestUtils testLocationSFO], [UALocationTestUtils testLocationPDX]]];
    XCTAssertTrue(_locationService.singleLocationShutdownScheduled, @"singleLocationShutdownScheduled should be YES");

    _timeout = [NSDate dateWithTimeIntervalSinceNow:10.0];

    while (!shutdownCalled) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        if ([_timeout timeIntervalSinceNow] < 0.0) {
            break;
        }
    }
    
    XCTAssertTrue(shutdownCalled, @"Location service should be shutdown when a location cannot be obtained within timeout limits");
    [mockLocationService stopMocking];
}

- (void)testStopSingleLocationSetsShutdownScheduledFlag {
    _locationService.singleLocationShutdownScheduled = YES;
    [_locationService stopSingleLocation];
    XCTAssertFalse(_locationService.singleLocationShutdownScheduled, @"singleLocationServiceShutdownScheduled should be NO after stopSingleLocation");
}

- (void)testReportCurrentLocationShutsDownBackgroundTaskOnError {
    _locationService = [[UALocationService alloc] init];
    id mockLocationService = [OCMockObject partialMockForObject:_locationService];
    [[[mockLocationService stub] andReturnValue:OCMOCK_VALUE(YES)] isLocationServiceEnabledAndAuthorized];
    _locationService.singleLocationProvider = [UAStandardLocationProvider providerWithDelegate:_locationService];

    id mockProvider = [OCMockObject partialMockForObject:_locationService.singleLocationProvider];
    [[mockProvider stub] startReportingLocation];
    [_locationService reportCurrentLocation];
    XCTAssertFalse(_locationService.singleLocationBackgroundIdentifier == UIBackgroundTaskInvalid, @"LocationService background identifier should be valid");

    [_locationService.singleLocationProvider.delegate locationProvider:_locationService.singleLocationProvider 
                                                  withLocationManager:_locationService.singleLocationProvider.locationManager 
                                                     didFailWithError:[NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil]];
     XCTAssertTrue(_locationService.singleLocationBackgroundIdentifier == UIBackgroundTaskInvalid, @"LcoationService background identifier should be invalid");
    
    [mockLocationService stopMocking];
    [mockProvider stopMocking];
}

#pragma mark -
#pragma mark Last Location and Date

- (void)testLastLocationAndDate {
    _locationService = [[UALocationService alloc] init];
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    [_locationService reportLocationToAnalytics:pdx fromProvider:_locationService.standardLocationProvider];
    XCTAssertEqualObjects(pdx, _locationService.lastReportedLocation);
    NSTimeInterval smallAmountOfTime = [_locationService.dateOfLastLocation timeIntervalSinceNow];
    XCTAssertEqualWithAccuracy(smallAmountOfTime, 0.1, 0.5);
}

#pragma mark -
#pragma mark UALocationService Delegate methods

- (void)locationService:(UALocationService*)service didFailWithError:(NSError*)error {
    NSLog(@"Location error received %@", error);
    _errorReceived = YES;
}
- (void)locationService:(UALocationService*)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"Authorization status changed to %u",status);
}
- (void)locationService:(UALocationService*)service didUpdateLocations:(NSArray *)locations {
    NSLog(@"Location received");
    _locationReceived = YES;
}
                                                                            
- (void)peformInvocationInBackground:(NSInvocation *)invocation {
    @autoreleasepool {
        [invocation invoke];
    }
}

- (void)testSignificantChangeNotifiesDelegate {
    _locationService = [[UALocationService alloc] init];
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];

    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    [[mockDelegate expect] locationService:_locationService didUpdateLocations:@[sfo, pdx]];
    UASignificantChangeProvider *sigChange = [UASignificantChangeProvider providerWithDelegate:_locationService];
    _locationService.significantChangeProvider = sigChange;
    _locationService.delegate = mockDelegate;
    [sigChange.delegate locationProvider:sigChange withLocationManager:[sigChange locationManager] didUpdateLocations:@[sfo, pdx]];
    [mockDelegate verify];
    [mockDelegate stopMocking];
}

@end
