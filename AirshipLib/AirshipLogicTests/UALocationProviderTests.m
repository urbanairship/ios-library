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
#import <SenTestingKit/SenTestingKit.h>
#import "UALocationTestUtils.h"
#import "UALocationCommonValues.h"
#import "UABaseLocationProvider.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"


/*  testing all the delegates in one class because
 *  they are all small. If this changes, break them out 
 *  to their own files
 */

@interface UALocationProviderTests : SenTestCase

@property (nonatomic, strong) id<UALocationProviderDelegate> mockUALocationService;
@property (nonatomic, strong) CLLocation *testLocationPDX;
@property (nonatomic, strong) CLLocation *testLocationSFO;

// This is a fragile test support method, do not use in production without some additional work. 
- (BOOL)regexString:(NSString *)target forRegexPattern:(NSString *)regexPattern;
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

//- (void)testInitWithDelegate {
//    id mockLocationService = [OCMockObject mockForProtocol:@protocol(UALocationProviderDelegate)];
//    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:mockLocationService];
//    STAssertEquals(base.provider, UALocationServiceProviderUnknown, @"base.provider should be UNKNOWN");
//    STAssertEqualObjects(mockLocationService, base.delegate, nil);
//    NSTimeInterval time = 300.0;
//    STAssertEquals(base.maximumElapsedTimeForCachedLocation, time, nil);
//}

- (void)testLocationProviderDescription {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:nil];
    base.serviceStatus = UALocationProviderNotUpdating;
    base.purpose = @"CATS";
    base.distanceFilter = 21;
    base.desiredAccuracy = 21;
    NSString *description = base.description;

    // check for Provider Purpose Updating
    STAssertTrue([self regexString:description forRegexPattern:@"Provider"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"Purpose"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"Updating"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"\\w:0"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"CATS"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"UNKNOWN"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"desiredAccuracy"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"distanceFilter"], nil);

    NSString *distanceFilterRegex = [NSString stringWithFormat:@"%f", base.distanceFilter];
    NSString *desiredAccueracyRegex = [NSString stringWithFormat:@"%f", base.desiredAccuracy];
    STAssertTrue([self regexString:description forRegexPattern:distanceFilterRegex], nil);
    STAssertTrue([self regexString:description forRegexPattern:desiredAccueracyRegex    ], nil);
}

- (void)testRegexSupport {
    STAssertTrue([self regexString:@"CATS" forRegexPattern:@"CA"], nil);
    STAssertFalse([self regexString:@"CATS" forRegexPattern:@"BORK"], nil);
}

// Returns yes if one or more matches exist in the string
- (BOOL)regexString:(NSString*)target forRegexPattern:(NSString*)regexPattern {
    NSError *regexError = nil;

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern options:NSRegularExpressionCaseInsensitive error:&regexError];
    STAssertNil(regexError, nil);

    NSUInteger match = [regex numberOfMatchesInString:target options:0 range:NSMakeRange(0, target.length)];
    return (match >= 1);
}

- (void)testStandardInitWithDelegate {
    id mockUALocationService = [OCMockObject mockForProtocol:@protocol(UALocationProviderDelegate)];
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:mockUALocationService];
    STAssertNotNil(standard, nil);
    STAssertEquals(standard.provider, UALocationServiceProviderGps, @"provider should be GPS");
    STAssertEqualObjects(mockUALocationService, standard.delegate, nil);
}

- (void)testSignificantChangeInitWithDelegate {
    id mockUALocationService = [OCMockObject mockForProtocol:@protocol(UALocationProviderDelegate)];
    UASignificantChangeProvider *delegate = [UASignificantChangeProvider providerWithDelegate:mockUALocationService];
    STAssertNotNil(delegate, nil);
    STAssertEquals(delegate.provider, UALocationServiceProviderNetwork, @"provider should be NETWORK");
    STAssertEqualObjects(mockUALocationService, delegate.delegate, nil);
}

- (void)testCLLocationManagerSetter {
    UABaseLocationProvider *provider = [[UABaseLocationProvider alloc] init];
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    provider.locationManager = locationManager;

    STAssertEqualObjects(locationManager.delegate, provider, @"The CLLocationManger delegate is not being set properly");

    // The service reports not updating
    STAssertEquals(provider.serviceStatus, UALocationProviderNotUpdating, nil);
}

- (void)testUABaseProviderCLLocationManagerGetSetMethods {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] init];
    base.distanceFilter = 5.0;
    base.desiredAccuracy = 5.0;

    STAssertEquals(base.locationManager.distanceFilter, 5.0, nil);
    STAssertEquals(base.locationManager.desiredAccuracy, 5.0, nil);
    STAssertEquals(base.distanceFilter, 5.0, nil);
    STAssertEquals(base.desiredAccuracy, 5.0, nil);
}

#pragma mark -
#pragma mark Location Provider Accuracy calculations

- (void)testCachedLocation {
    id mockLocation = [OCMockObject niceMockForClass:[CLLocationManager class]];
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] init];
    base.locationManager = mockLocation;

    [(CLLocationManager *)[mockLocation expect] location];
    [base location];
    [mockLocation verify];
}

- (void)testBaseProviderAccuracyFailsOnInvalidLocation {
    CLLocationAccuracy accuracy = -5.0;
    id mockLocation = [OCMockObject niceMockForClass:[CLLocation class]];

    [[[mockLocation stub] andReturnValue:OCMOCK_VALUE(accuracy)] horizontalAccuracy];
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] init];
    STAssertFalse([base locationChangeMeetsAccuracyRequirements:mockLocation from:self.testLocationSFO], @"Accuracy less than zero should fail");

    accuracy = 5.0;
    mockLocation = [OCMockObject niceMockForClass:[CLLocation class]];
    [[[mockLocation stub] andReturnValue:OCMOCK_VALUE(accuracy)] horizontalAccuracy];
    STAssertTrue([base locationChangeMeetsAccuracyRequirements:mockLocation from:self.testLocationSFO], nil);
}

- (void)testBaseProviderAccuracyTimestampCalculation {
    NSDate *date = [NSDate date];
    id location = [OCMockObject niceMockForClass:[CLLocation class]];

    [(CLLocation *)[[location stub] andReturn:date] timestamp];
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] init];
    STAssertTrue([base locationChangeMeetsAccuracyRequirements:location from:self.testLocationSFO], nil);

    base.maximumElapsedTimeForCachedLocation = 20.0;
    date = [NSDate dateWithTimeIntervalSinceNow:-50];
    location = [OCMockObject niceMockForClass:[CLLocation class]];
    [(CLLocation *)[[location stub] andReturn:date] timestamp];
    STAssertFalse([base locationChangeMeetsAccuracyRequirements:location from:self.testLocationSFO], nil);
}

#pragma mark -
#pragma mark Delegate Callbacks To UALocationService

- (void)testBaseDelegateCallbackForLocation {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockForBase = [OCMockObject partialMockForObject:base];

    [[[mockForBase  expect] andReturnValue:@YES] locationChangeMeetsAccuracyRequirements:self.testLocationPDX from:self.testLocationSFO];
    [[(OCMockObject *)self.mockUALocationService expect] locationProvider:base
                                                      withLocationManager:base.locationManager
                                                        didUpdateLocation:self.testLocationPDX
                                                             fromLocation:self.testLocationSFO];

    // base.locationMananger would call its delegate, UABaseLocationDelegate would test, then call UALocationService
    [base.locationManager.delegate locationManager:base.locationManager
                               didUpdateToLocation:self.testLocationPDX
                                      fromLocation:self.testLocationSFO];

    [(OCMockObject *)self.mockUALocationService verify];
    [mockForBase verify];
}

- (void)testStandardDelegateCallbackForLocation {
    UAStandardLocationProvider *standard = [[UAStandardLocationProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockForStandard = [OCMockObject partialMockForObject:standard];
    
    //- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation*)oldLocation to:(CLLocation*)newLocation
    [[[mockForStandard  expect] andReturnValue:@YES] locationChangeMeetsAccuracyRequirements:self.testLocationPDX
                                                                                        from:self.testLocationSFO];
    [[(OCMockObject *) self.mockUALocationService expect] locationProvider:standard
                                                       withLocationManager:standard.locationManager
                                                         didUpdateLocation:self.testLocationPDX
                                                              fromLocation:self.testLocationSFO];

    // base.locationMananger would call its delegate, UABaseLocationDelegate would test, then call UALocationService
    [standard.locationManager.delegate locationManager:standard.locationManager
                                   didUpdateToLocation:self.testLocationPDX
                                          fromLocation:self.testLocationSFO];
    [(OCMockObject *)self.mockUALocationService verify];
    [mockForStandard verify];
}

- (void)testSignificantChangeCallbackForLocation {
    UASignificantChangeProvider *significant = [[UASignificantChangeProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockForSignificant = [OCMockObject partialMockForObject:significant];

    [[[mockForSignificant  expect] andReturnValue:@YES]locationChangeMeetsAccuracyRequirements:self.testLocationPDX
                                                                                          from:self.testLocationSFO];
    [[(OCMockObject *) self.mockUALocationService expect] locationProvider:significant
                                                       withLocationManager:significant.locationManager
                                                         didUpdateLocation:self.testLocationPDX
                                                              fromLocation:self.testLocationSFO];
    // base.locationMananger would call its delegate, UABaseLocationDelegate would test, then call UALocationService
    [significant.locationManager.delegate locationManager:significant.locationManager
                                      didUpdateToLocation:self.testLocationPDX
                                             fromLocation:self.testLocationSFO];
    [(OCMockObject *)self.mockUALocationService verify];
    [mockForSignificant verify];
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

}

- (void)testAuthorizationChangeSignificantDelegateResponse {
    UASignificantChangeProvider *significant = [[UASignificantChangeProvider alloc] initWithDelegate:self.mockUALocationService];
    id mockLocationManager = [OCMockObject partialMockForObject:significant.locationManager];

    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [significant.locationManager.delegate locationManager:significant.locationManager
                             didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockLocationManager verify];

    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [significant.locationManager.delegate locationManager:significant.locationManager
                             didChangeAuthorizationStatus:kCLAuthorizationStatusRestricted];
    [mockLocationManager verify];

    [[mockLocationManager reject] stopMonitoringSignificantLocationChanges];
    [significant.locationManager.delegate locationManager:significant.locationManager
                             didChangeAuthorizationStatus:kCLAuthorizationStatusNotDetermined];
    [significant.locationManager.delegate locationManager:significant.locationManager
                             didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized];
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
    STAssertEquals(standardProvider.serviceStatus, UALocationProviderUpdating, nil);

    [standardProvider stopReportingLocation];
    STAssertEquals(standardProvider.serviceStatus, UALocationProviderNotUpdating, nil);
    [mockLocationManager verify];
}

- (void)testStartStopProvidingSignificantChange {
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    UASignificantChangeProvider *significantChange = [UASignificantChangeProvider providerWithDelegate:nil];
    significantChange.locationManager = mockLocationManager;

    [[mockLocationManager expect] startMonitoringSignificantLocationChanges];
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [significantChange startReportingLocation];
    STAssertEquals(significantChange.serviceStatus, UALocationProviderUpdating, nil);

    [significantChange stopReportingLocation];
    STAssertEquals(significantChange.serviceStatus, UALocationProviderNotUpdating, nil);
    [mockLocationManager verify];
}


@end
