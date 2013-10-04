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

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import <XCTest/XCTest.h>
#import "UALocationTestUtils.h"
#import "UALocationCommonValues.h"
#import "UABaseLocationProvider.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"

/*  testing all the delegates in one class because
 *  they are all small. If this changes, break them out 
 *  to their own files
 */

@interface UALocationProviderTests : XCTestCase

@property (nonatomic, strong) id<UALocationProviderDelegate> mockUALocationService;
@property (nonatomic, strong) CLLocation *testLocationPDX;
@property (nonatomic, strong) CLLocation *testLocationSFO;
@end

@implementation UALocationProviderTests

- (void)setUp {
    self.mockUALocationService = [OCMockObject niceMockForProtocol:@protocol(UALocationProviderDelegate)];
    self.testLocationPDX = [UALocationTestUtils testLocationPDX];
    self.testLocationSFO = [UALocationTestUtils testLocationSFO];
}

- (void)tearDown {
    self.mockUALocationService = nil;
    self.testLocationPDX = nil;
    self.testLocationSFO = nil;
}

#pragma mark -
#pragma mark Initialization

- (void)testInitWithDelegate {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:self.mockUALocationService];

    XCTAssertEqual(UALocationServiceProviderUnknown, base.provider, @"Base Provider should be UNKNOWN");
    XCTAssertEqualObjects(self.mockUALocationService, base.delegate, @"Location provider delegate is not being set.");
    XCTAssertEqual(300.0, base.maximumElapsedTimeForCachedLocation, @"Default maximumElapsedTimeForCachedLocation is not set");
}

- (void)testStandardInitWithDelegate {
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:self.mockUALocationService];

    XCTAssertEqual(UALocationServiceProviderGps, standard.provider, @"Standard Provider should be GPS");
    XCTAssertEqualObjects(self.mockUALocationService, standard.delegate, @"Location provider delegate is not being set.");
    XCTAssertEqual(300.0, standard.maximumElapsedTimeForCachedLocation, @"Default maximumElapsedTimeForCachedLocation is not set");
}

- (void)testSignificantChangeInitWithDelegate {
    UASignificantChangeProvider *significant = [UASignificantChangeProvider providerWithDelegate:self.mockUALocationService];

    XCTAssertEqual(UALocationServiceProviderNetwork, significant.provider, @"Standard Provider should be NETWORK");
    XCTAssertEqualObjects(self.mockUALocationService, significant.delegate, @"Location provider delegate is not being set.");
    XCTAssertEqual(300.0, significant.maximumElapsedTimeForCachedLocation, @"Default maximumElapsedTimeForCachedLocation is not set");
}

- (void)testLocationProviderDescription {
    UABaseLocationProvider *provider = [[UABaseLocationProvider alloc] initWithDelegate:nil];
    provider.purpose = @"CATS";
    provider.distanceFilter = 21;
    provider.desiredAccuracy = 21;

    NSString *expectedDescription = @"Provider:UNKNOWN, Purpose:CATS, Updating:0, desiredAccuracy 21.000000, distanceFilter 21.000000";
    XCTAssertEqualObjects(expectedDescription, provider.description, @"Provider description is unexpected");
}

- (void)testCLLocationManagerSetter {
    UABaseLocationProvider *provider = [[UABaseLocationProvider alloc] init];
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    provider.locationManager = locationManager;

    XCTAssertEqualObjects(locationManager.delegate, provider, @"The CLLocationManger delegate is not being set properly");
    XCTAssertEqual(provider.serviceStatus, UALocationProviderNotUpdating, @"The service status should not be updating");
}

- (void)testUABaseProviderCLLocationManagerGetSetMethods {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] init];
    base.distanceFilter = 5.0;
    base.desiredAccuracy = 10.0;

    XCTAssertEqual(base.locationManager.distanceFilter, 5.0, @"Location provider not setting locationManager distance filter");
    XCTAssertEqual(base.locationManager.desiredAccuracy, 10.0, @"Location provider not setting the locationManager desired accuracy");
    XCTAssertEqual(base.distanceFilter, 5.0, @"Location providers is not returning the correct distance filter");
    XCTAssertEqual(base.desiredAccuracy, 10.0, @"Location providers is not returning the correct desired accuracy");
}

#pragma mark -
#pragma mark Location Provider Accuracy calculations
- (void)testBaseProviderAccuracyFailsOnInvalidLocation {
    CLLocationAccuracy accuracy = -5.0;
    id mockLocation = [OCMockObject niceMockForClass:[CLLocation class]];

    [[[mockLocation stub] andReturnValue:OCMOCK_VALUE(accuracy)] horizontalAccuracy];
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] init];
    XCTAssertFalse([base locationChangeMeetsAccuracyRequirements:mockLocation from:self.testLocationSFO], @"Accuracy less than zero should fail");

    accuracy = 5.0;
    mockLocation = [OCMockObject niceMockForClass:[CLLocation class]];
    [[[mockLocation stub] andReturnValue:OCMOCK_VALUE(accuracy)] horizontalAccuracy];
    XCTAssertTrue([base locationChangeMeetsAccuracyRequirements:mockLocation from:self.testLocationSFO]);

    [mockLocation stopMocking];
}

- (void)testBaseProviderAccuracyTimestampCalculation {
    NSDate *date = [NSDate date];
    id location = [OCMockObject niceMockForClass:[CLLocation class]];

    [(CLLocation *)[[location stub] andReturn:date] timestamp];
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] init];
    XCTAssertTrue([base locationChangeMeetsAccuracyRequirements:location from:self.testLocationSFO]);

    base.maximumElapsedTimeForCachedLocation = 20.0;
    date = [NSDate dateWithTimeIntervalSinceNow:-50];
    location = [OCMockObject niceMockForClass:[CLLocation class]];
    [(CLLocation *)[[location stub] andReturn:date] timestamp];
    XCTAssertFalse([base locationChangeMeetsAccuracyRequirements:location from:self.testLocationSFO]);

    [location stopMocking];
}

#pragma mark -
#pragma mark Delegate Callbacks To UALocationService

- (void)testBaseDelegateCallbackForLocation {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockForBase = [OCMockObject partialMockForObject:base];

    [[[mockForBase  expect] andReturnValue:OCMOCK_VALUE(YES)] locationChangeMeetsAccuracyRequirements:self.testLocationPDX from:self.testLocationSFO];
    [[(OCMockObject *)self.mockUALocationService expect] locationProvider:base
                                                      withLocationManager:base.locationManager
                                                        didUpdateLocation:self.testLocationPDX
                                                             fromLocation:self.testLocationSFO];


    [base.locationManager.delegate locationManager:base.locationManager
                               didUpdateToLocation:self.testLocationPDX
                                      fromLocation:self.testLocationSFO];

    [(OCMockObject *)self.mockUALocationService verify];
    [mockForBase verify];

    [mockForBase stopMocking];
}

- (void)testStandardDelegateCallbackForLocation {
    UAStandardLocationProvider *standard = [[UAStandardLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockForStandard = [OCMockObject partialMockForObject:standard];
    
    [[[mockForStandard  expect] andReturnValue:OCMOCK_VALUE(YES)] locationChangeMeetsAccuracyRequirements:self.testLocationPDX
                                                                                        from:self.testLocationSFO];
    [[(OCMockObject *) self.mockUALocationService expect] locationProvider:standard
                                                       withLocationManager:standard.locationManager
                                                         didUpdateLocation:self.testLocationPDX
                                                              fromLocation:self.testLocationSFO];


    [standard.locationManager.delegate locationManager:standard.locationManager
                                   didUpdateToLocation:self.testLocationPDX
                                          fromLocation:self.testLocationSFO];
    [(OCMockObject *)self.mockUALocationService verify];
    [mockForStandard verify];

    [mockForStandard stopMocking];
}

- (void)testSignificantChangeCallbackForLocation {
    UASignificantChangeProvider *significant = [[UASignificantChangeProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockForSignificant = [OCMockObject partialMockForObject:significant];

    [[[mockForSignificant  expect] andReturnValue:OCMOCK_VALUE(YES)]locationChangeMeetsAccuracyRequirements:self.testLocationPDX
                                                                                          from:self.testLocationSFO];
    [[(OCMockObject *) self.mockUALocationService expect] locationProvider:significant
                                                       withLocationManager:significant.locationManager
                                                         didUpdateLocation:self.testLocationPDX
                                                              fromLocation:self.testLocationSFO];

    [significant.locationManager.delegate locationManager:significant.locationManager
                                      didUpdateToLocation:self.testLocationPDX
                                             fromLocation:self.testLocationSFO];
    [(OCMockObject *)self.mockUALocationService verify];
    [mockForSignificant verify];

    [mockForSignificant stopMocking];
}

#pragma mark -
#pragma mark CLLocationManager Authorization Changes

- (void)testAuthorizationChangeBaseDelegateResponse {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockLocationManager = [OCMockObject partialMockForObject:base.locationManager];

    [[mockLocationManager expect] stopUpdatingHeading];
    [[mockLocationManager expect] stopUpdatingLocation];
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [base.locationManager.delegate locationManager:base.locationManager
                      didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockLocationManager verify];

    [[mockLocationManager expect] stopUpdatingHeading];
    [[mockLocationManager expect] stopUpdatingLocation];
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [base.locationManager.delegate locationManager:base.locationManager
                      didChangeAuthorizationStatus:kCLAuthorizationStatusRestricted];
    [mockLocationManager verify];

    [[mockLocationManager reject] stopUpdatingHeading];
    [[mockLocationManager reject] stopUpdatingLocation];
    [[mockLocationManager reject] stopMonitoringSignificantLocationChanges];
    [base.locationManager.delegate locationManager:base.locationManager
                      didChangeAuthorizationStatus:kCLAuthorizationStatusNotDetermined];
    [base.locationManager.delegate locationManager:base.locationManager
                      didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized];

    [mockLocationManager stopMocking];
}

- (void)testAuthorizationChangedStandardDelegateResponse {
    UAStandardLocationProvider *standard = [[UAStandardLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockLocationManager = [OCMockObject partialMockForObject:standard.locationManager];


    [[mockLocationManager expect] stopUpdatingLocation];
    [standard.locationManager.delegate locationManager:standard.locationManager
                          didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockLocationManager verify];

    [[mockLocationManager expect] stopUpdatingLocation];
    [standard.locationManager.delegate locationManager:standard.locationManager
                          didChangeAuthorizationStatus:kCLAuthorizationStatusRestricted];
    [mockLocationManager verify];


    [[mockLocationManager reject] stopUpdatingLocation];
    [standard.locationManager.delegate locationManager:standard.locationManager
                          didChangeAuthorizationStatus:kCLAuthorizationStatusNotDetermined];
    [standard.locationManager.delegate locationManager:standard.locationManager
                          didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized];

    [mockLocationManager stopMocking];
}

- (void)testAuthorizationChangeSignificantDelegateResponse {
    UASignificantChangeProvider *significant = [[UASignificantChangeProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockLocationManager = [OCMockObject partialMockForObject:significant.locationManager];

    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [significant.locationManager.delegate locationManager:significant.locationManager
                             didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];

    XCTAssertNoThrow([mockLocationManager verify]);

    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [significant.locationManager.delegate locationManager:significant.locationManager
                             didChangeAuthorizationStatus:kCLAuthorizationStatusRestricted];

    XCTAssertNoThrow([mockLocationManager verify]);

    [[mockLocationManager reject] stopMonitoringSignificantLocationChanges];
    XCTAssertNoThrow([significant.locationManager.delegate locationManager:significant.locationManager
                                             didChangeAuthorizationStatus:kCLAuthorizationStatusNotDetermined], @"Failed");

    XCTAssertNoThrow([significant.locationManager.delegate locationManager:significant.locationManager
                             didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized], @"I failed");

    [mockLocationManager stopMocking];
}


#pragma mark -
#pragma mark CLLocationManager didFailWithError

- (void)testDidFailWithErrorNonShutdown {
    NSError *testError = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockBase = [OCMockObject partialMockForObject:base];

    [[[mockBase expect] andForwardToRealObject] locationManager:base.locationManager didFailWithError:testError];
    [[(OCMockObject *) self.mockUALocationService expect] locationProvider:base
                                                      withLocationManager:base.locationManager
                                                         didFailWithError:testError];
    [base.locationManager.delegate locationManager:base.locationManager didFailWithError:testError];
    [(OCMockObject *)self.mockUALocationService verify];
    [mockBase verify];
    [mockBase stopMocking];
}

// Test the two cases where UABaseLocationProvider needs to shutdown
- (void)testDidFailWithErrorShutdown {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockBase = [OCMockObject partialMockForObject:base];
    [[mockBase expect] stopReportingLocation];

    NSError *error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorNetwork userInfo:nil];
    [base.locationManager.delegate locationManager:base.locationManager didFailWithError:error];
    [mockBase verify];

    error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
    [[mockBase expect] stopReportingLocation];
    [base.locationManager.delegate locationManager:base.locationManager didFailWithError:error];
    [mockBase verify];
    [mockBase stopMocking];
}

- (void)testDidFailWithErrorStandard {
    UABaseLocationProvider *standard = [[UAStandardLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockStandard = [OCMockObject partialMockForObject:standard];
    NSError *test = [NSError errorWithDomain:@"test" code:0 userInfo:nil];

    [[[mockStandard expect] andForwardToRealObject] locationManager:standard.locationManager didFailWithError:test];
    [[(OCMockObject *) self.mockUALocationService expect] locationProvider:standard
                                                       withLocationManager:standard.locationManager
                                                          didFailWithError:test];
    [standard.locationManager.delegate locationManager:standard.locationManager didFailWithError:test];
    [(OCMockObject *)self.mockUALocationService verify];
    [mockStandard verify];
    [mockStandard stopMocking];
}

- (void)testDidFailWithErrorSignificant {
    UASignificantChangeProvider *significant = [[UASignificantChangeProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockSignificant = [OCMockObject partialMockForObject:significant];
    NSError* test = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    [[[mockSignificant expect] andForwardToRealObject] locationManager:significant.locationManager didFailWithError:test];
    [[(OCMockObject *) self.mockUALocationService expect] locationProvider:significant
                                                       withLocationManager:significant.locationManager
                                                          didFailWithError:test];

    [significant.locationManager.delegate locationManager:significant.locationManager didFailWithError:test];
    [(OCMockObject *)self.mockUALocationService verify];
    [mockSignificant verify];
    [mockSignificant stopMocking];
}

#pragma mark -
#pragma mark Start/Stop Providing location

- (void)testStartStopProvidingStandardLocation {
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    UAStandardLocationProvider *standardProvider = [UAStandardLocationProvider providerWithDelegate:nil];
    standardProvider.locationManager = mockLocationManager;

    [[mockLocationManager expect] startUpdatingLocation];
    [[mockLocationManager expect] stopUpdatingLocation];
    [standardProvider startReportingLocation];
    XCTAssertEqual(standardProvider.serviceStatus, UALocationProviderUpdating);

    [standardProvider stopReportingLocation];
    XCTAssertEqual(standardProvider.serviceStatus, UALocationProviderNotUpdating);
    [mockLocationManager verify];
    [mockLocationManager stopMocking];
}

- (void)testStartStopProvidingSignificantChange {
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    UASignificantChangeProvider *significantChange = [UASignificantChangeProvider providerWithDelegate:nil];
    significantChange.locationManager = mockLocationManager;

    [[mockLocationManager expect] startMonitoringSignificantLocationChanges];
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [significantChange startReportingLocation];
    XCTAssertEqual(significantChange.serviceStatus, UALocationProviderUpdating);

    [significantChange stopReportingLocation];
    XCTAssertEqual(significantChange.serviceStatus, UALocationProviderNotUpdating);
    [mockLocationManager verify];
    [mockLocationManager stopMocking];
}


@end
