/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
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


/** testing all the delegates in one class because
 *  they are all small. If this changes, break them out 
 *  to there own files
 */

@interface UALocationProviderTests : SenTestCase {
    id <UALocationProviderDelegate> mockUALocationService_;
    CLLocation *testLocationPDX_;
    CLLocation *testLocationSFO_;
    BOOL yes;
    BOOL no;
}
@property (nonatomic, retain) id <UALocationProviderDelegate> mockUALocationService;
@property (nonatomic, retain) CLLocation *testLocationPDX;
@property (nonatomic, retain) CLLocation *testLocationSFO;

// This is a fragile test support method, do not use in production without some additional work. 
- (BOOL)regexString:(NSString*)target forRegexPattern:(NSString*)regexPattern;
@end

@implementation UALocationProviderTests
@synthesize mockUALocationService = mockUALocationService_;
@synthesize testLocationPDX = testLocationPDX_;
@synthesize testLocationSFO = testLocationSFO_;

- (void)setUp {
    self.mockUALocationService = [OCMockObject niceMockForProtocol:@protocol(UALocationProviderDelegate)];
    self.testLocationPDX = [UALocationTestUtils testLocationPDX];
    self.testLocationSFO = [UALocationTestUtils testLocationSFO];
    yes = YES;
    no = NO;
}

- (void)tearDown {
    RELEASE(mockUALocationService_);
    RELEASE(testLocationPDX_);
    RELEASE(testLocationSFO_);
}
#pragma mark -
#pragma mark Initialization

- (void)testInitWithDelegate {
    id mockLocationService = [OCMockObject mockForProtocol:@protocol(UALocationProviderDelegate)];
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:mockLocationService];
    STAssertEquals(base.provider, UALocationServiceProviderUnknown, @"base.provider should be UNKNOWN");
    STAssertEqualObjects(mockLocationService, base.delegate, nil);
}

- (void)testNilDelegateOnRelease {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:mockUALocationService_];
    // Get a reference to the location manager, and keep it after releasing the UABaseLocationProvider
    CLLocationManager *manager = [base.locationManager retain];
    [base release];
    // Not setting the delegate to nil could result in a crash
    STAssertNil(manager.delegate, @"UABaseLocationManager should nil the delegate on release");
    [manager autorelease];
}

//TODO: add accuracy calculations here. 

- (void)testLocationProviderDescription {
    UABaseLocationProvider *base = [[[UABaseLocationProvider alloc] initWithDelegate:nil] autorelease];
    base.serviceStatus = UALocationProviderNotUpdating;
    base.purpose = @"CATS";
    NSString *description = base.description;
    // check for Provider Purpose Updating
    STAssertTrue([self regexString:description forRegexPattern:@"Provider"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"Purpose"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"Updating"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"\\w:0"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"CATS"], nil);
    STAssertTrue([self regexString:description forRegexPattern:@"UNKNOWN"], nil);
}

- (void)testRegexSupport {
    STAssertTrue([self regexString:@"CATS" forRegexPattern:@"CA"] ,nil);
    STAssertFalse([self regexString:@"CATS" forRegexPattern:@"BORK"] ,nil);
}

- (BOOL)regexString:(NSString*)target forRegexPattern:(NSString*)regexPattern {
    NSError *regexError = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern options:NSRegularExpressionCaseInsensitive error:&regexError];
    STAssertNil(regexError,nil);
    NSUInteger match = [regex numberOfMatchesInString:target options:NSRegularExpressionCaseInsensitive range:NSMakeRange(0, target.length)];
    return match == 1 ? YES:NO;
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
    UABaseLocationProvider* provider = [[UABaseLocationProvider alloc] init];
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    provider.locationManager = locationManager;
    STAssertEqualObjects(locationManager.delegate, provider, @"The CLLocationManger delegate is not being set properly");
    // The service reports not updating
    STAssertEquals(provider.serviceStatus, UALocationProviderNotUpdating, nil);
    [provider release];
    [locationManager release];
}

- (void)testUABaseProviderCLLocationManagerGetSetMethods {
    UABaseLocationProvider* base = [[[UABaseLocationProvider alloc] init] autorelease];
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
    UABaseLocationProvider *base = [[[UABaseLocationProvider alloc] init] autorelease];
    base.locationManager = mockLocation;
    [[mockLocation expect] location];
    [base location];
    [mockLocation verify];
}

- (void)testBaseProviderAccuracyFailsOnInvalidLocation {
    id mockLocation = [OCMockObject niceMockForClass:[CLLocation class]];
    CLLocationAccuracy accuracy = -5.0;
    [[[mockLocation stub] andReturnValue:OCMOCK_VALUE(accuracy)] horizontalAccuracy];
    UABaseLocationProvider *base = [[[UABaseLocationProvider alloc] init] autorelease];
    STAssertFalse([base locationChangeMeetsAccuracyRequirements:mockLocation from:testLocationSFO_], @"Accuracy less than zero should fail");
    accuracy = 5.0;
    mockLocation = [OCMockObject niceMockForClass:[CLLocation class]];
    [[[mockLocation stub] andReturnValue:OCMOCK_VALUE(accuracy)] horizontalAccuracy];
    STAssertTrue([base locationChangeMeetsAccuracyRequirements:mockLocation from:testLocationSFO_], nil);
}

- (void)testBaseProviderAccuracyTimestampCalculation {
    NSDate *date = [NSDate date];
    id location = [OCMockObject niceMockForClass:[CLLocation class]];
    [(CLLocation*)[[location stub] andReturn:date] timestamp];
    UABaseLocationProvider *base = [[[UABaseLocationProvider alloc] init] autorelease];
    STAssertTrue([base locationChangeMeetsAccuracyRequirements:location from:testLocationSFO_], nil);
    date = [NSDate dateWithTimeIntervalSinceNow:-400];
    location = [OCMockObject niceMockForClass:[CLLocation class]];
    [(CLLocation*)[[location stub] andReturn:date] timestamp];
    STAssertFalse([base locationChangeMeetsAccuracyRequirements:location from:testLocationSFO_], nil);
}

#pragma mark -
#pragma mark Delegate Callbacks To UALocationService

#pragma mark CLLocationManager didUpdateToLocation

- (void)testBaseDelegateCallbackForLocation {
    UABaseLocationProvider *base = [[UABaseLocationProvider alloc] initWithDelegate:mockUALocationService_];
    id mockForBase = [OCMockObject partialMockForObject:base];
    //- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation*)oldLocation to:(CLLocation*)newLocation
    [[[mockForBase  expect] andReturnValue:OCMOCK_VALUE(yes)] locationChangeMeetsAccuracyRequirements:testLocationPDX_ from:testLocationSFO_];
    [[(OCMockObject*) mockUALocationService_ expect] locationProvider:base withLocationManager:base.locationManager didUpdateLocation:testLocationPDX_ fromLocation:testLocationSFO_];
    // base.locationMananger would call its delegate, UABaseLocationDelegate would test, then call UALocationService
    [base.locationManager.delegate locationManager:base.locationManager didUpdateToLocation:testLocationPDX_ fromLocation:testLocationSFO_];
    [(OCMockObject*)mockUALocationService_ verify];
    [mockForBase verify];
    [base release];
}

- (void)testStandardDelegateCallbackForLocation {
    UAStandardLocationProvider *standard = [[UAStandardLocationProvider alloc] initWithDelegate:mockUALocationService_];
    id mockForStandard = [OCMockObject partialMockForObject:standard];
    //- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation*)oldLocation to:(CLLocation*)newLocation
    [[[mockForStandard  expect] andReturnValue:OCMOCK_VALUE(yes)] locationChangeMeetsAccuracyRequirements:testLocationPDX_ from:testLocationSFO_];
    [[(OCMockObject*) mockUALocationService_ expect] locationProvider:standard withLocationManager:standard.locationManager didUpdateLocation:testLocationPDX_ fromLocation:testLocationSFO_];
    // base.locationMananger would call its delegate, UABaseLocationDelegate would test, then call UALocationService
    [standard.locationManager.delegate locationManager:standard.locationManager didUpdateToLocation:testLocationPDX_ fromLocation:testLocationSFO_];
    [(OCMockObject*)mockUALocationService_ verify];
    [mockForStandard verify];
    [standard release];
}

- (void)testSignificantChangeCallbackForLocation {
    UASignificantChangeProvider *significant = [[UASignificantChangeProvider alloc] initWithDelegate:mockUALocationService_];
    id mockForSignificant = [OCMockObject partialMockForObject:significant];
    //- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation*)oldLocation to:(CLLocation*)newLocation
    [[[mockForSignificant  expect] andReturnValue:OCMOCK_VALUE(yes)]locationChangeMeetsAccuracyRequirements:testLocationPDX_ from:testLocationSFO_];
    [[(OCMockObject*) mockUALocationService_ expect] locationProvider:significant withLocationManager:significant.locationManager didUpdateLocation:testLocationPDX_ fromLocation:testLocationSFO_];
    // base.locationMananger would call its delegate, UABaseLocationDelegate would test, then call UALocationService
    [significant.locationManager.delegate locationManager:significant.locationManager didUpdateToLocation:testLocationPDX_ fromLocation:testLocationSFO_];
    [(OCMockObject*)mockUALocationService_ verify];
    [mockForSignificant verify];
    [significant release];
}

#pragma mark -
#pragma mark CLLocationManager Authorization Changes

- (void)testAuthorizationChangeBaseDelegateResponse {
    UABaseLocationProvider *base = [[[UABaseLocationProvider alloc] initWithDelegate:mockUALocationService_] autorelease];
    id mockLocationManager = [OCMockObject partialMockForObject:base.locationManager];
    [[mockLocationManager expect] stopUpdatingHeading];
    [[mockLocationManager expect] stopUpdatingLocation];
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [base.locationManager.delegate locationManager:base.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockLocationManager verify];
    [[mockLocationManager expect] stopUpdatingHeading];
    [[mockLocationManager expect] stopUpdatingLocation];
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [base.locationManager.delegate locationManager:base.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusRestricted];
    [mockLocationManager verify];
    [[mockLocationManager reject] stopUpdatingHeading];
    [[mockLocationManager reject] stopUpdatingLocation];
    [[mockLocationManager reject] stopMonitoringSignificantLocationChanges];
    [base.locationManager.delegate locationManager:base.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusNotDetermined];
    [base.locationManager.delegate locationManager:base.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized];
}

- (void)testAuthorizationChangedStandardDelegateResponse {
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:mockUALocationService_] autorelease];
    id mockLocationManager = [OCMockObject partialMockForObject:standard.locationManager];
    [[mockLocationManager expect] stopUpdatingLocation];
    [standard.locationManager.delegate locationManager:standard.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockLocationManager verify];
    [[mockLocationManager expect] stopUpdatingLocation];
    [standard.locationManager.delegate locationManager:standard.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusRestricted];
    [mockLocationManager verify];
    [[mockLocationManager reject] stopUpdatingLocation];
    [standard.locationManager.delegate locationManager:standard.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusNotDetermined];
    [standard.locationManager.delegate locationManager:standard.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized];

}

- (void)testAuthorizationChangeSignificantDelegateResponse {
    UASignificantChangeProvider *significant = [[[UASignificantChangeProvider alloc] initWithDelegate:mockUALocationService_] autorelease];
    id mockLocationManager = [OCMockObject partialMockForObject:significant.locationManager];
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [significant.locationManager.delegate locationManager:significant.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockLocationManager verify];
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [significant.locationManager.delegate locationManager:significant.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusRestricted];
    [mockLocationManager verify];
    [[mockLocationManager reject] stopMonitoringSignificantLocationChanges];
    [significant.locationManager.delegate locationManager:significant.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusNotDetermined];
    [significant.locationManager.delegate locationManager:significant.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized];
}


#pragma mark -
#pragma mark CLLocationManager didFailWithError

- (void)testDidFailWithErrorBase {
    UABaseLocationProvider *base = [[[UABaseLocationProvider alloc] initWithDelegate:mockUALocationService_] autorelease];
    id mockBase = [OCMockObject partialMockForObject:base];
    NSError* test = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    [[[mockBase expect] andForwardToRealObject] locationManager:base.locationManager didFailWithError:test];
    [[(OCMockObject*) mockUALocationService_ expect] locationProvider:base withLocationManager:base.locationManager didFailWithError:test];
    [base.locationManager.delegate locationManager:base.locationManager didFailWithError:test];
    [(OCMockObject*)mockUALocationService_ verify];
    [mockBase verify];
}

- (void)testDidFailWithErrorStandard {
    UABaseLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:mockUALocationService_] autorelease];
    id mockStandard = [OCMockObject partialMockForObject:standard];
    NSError* test = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    [[[mockStandard expect] andForwardToRealObject] locationManager:standard.locationManager didFailWithError:test];
    [[(OCMockObject*) mockUALocationService_ expect] locationProvider:standard withLocationManager:standard.locationManager didFailWithError:test];
    [standard.locationManager.delegate locationManager:standard.locationManager didFailWithError:test];
    [(OCMockObject*)mockUALocationService_ verify];
    [mockStandard verify];
}

- (void)testDidFailWithErrorSignificant {
    UASignificantChangeProvider *significant = [[[UASignificantChangeProvider alloc] initWithDelegate:mockUALocationService_] autorelease];
    id mockSignificant = [OCMockObject partialMockForObject:significant];
    NSError* test = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    [[[mockSignificant expect] andForwardToRealObject] locationManager:significant.locationManager didFailWithError:test];
    [[(OCMockObject*) mockUALocationService_ expect] locationProvider:significant withLocationManager:significant.locationManager didFailWithError:test];
    [significant.locationManager.delegate locationManager:significant.locationManager didFailWithError:test];
    [(OCMockObject*)mockUALocationService_ verify];
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
