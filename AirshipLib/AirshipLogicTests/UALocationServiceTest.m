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
#import "UAirship.h"
#import "UALocationEvent.h"
#import "UAAnalytics.h"
#import "UALocationCommonValues.h"
#import "UALocationService.h"
#import "UALocationService+Internal.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"
#import "UALocationTestUtils.h"
#import "JRSwizzle.h"
#import <SenTestingKit/SenTestingKit.h>

// This needs to be kept in sync with the value in UAirship

@interface UALocationService(Test)

+(BOOL)returnYES;
+(BOOL)returnNO;
@end
@implementation UALocationService(Test)

+(BOOL)returnYES {
    return YES;
}
+(BOOL)returnNO {
    return NO;
}

@end

@interface UALocationServiceTest : SenTestCase
{
    UALocationService *locationService;
    id mockLocationService; //[OCMockObject partialMockForObject:locationService]
    BOOL yes; // use for OCMockValue(val)
    BOOL no; // use for OCMockValue(val)
}
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
- (void)swizzleUALocationServiceClassMethod:(SEL)oneMethod withMethod:(SEL)anotherMethod;
- (void)swizzleCLLocationClassEnabledAndAuthorized;
- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized;
- (void)setTestValuesInNSUserDefaults;
@end


@implementation UALocationServiceTest


#pragma mark -
#pragma mark Setup Teardown

- (void)setUp {
    // Only works on the first pass, values will change when accessed. When fresh values are needed in 
    // user defaults call the setTestValuesInNSUserDefaults method
    [UAirship registerNSUserDefaults];
    yes = YES;
    no = NO;
    locationService = [[UALocationService alloc] initWithPurpose:@"TEST"];
    mockLocationService = [[OCMockObject partialMockForObject:locationService] retain];
}

- (void)tearDown {
    RELEASE(mockLocationService);
    RELEASE(locationService);
}

#pragma mark -
#pragma mark Basic Object Initialization

- (void)testBasicInit{
    [self setTestValuesInNSUserDefaults];
    UALocationService *testService = [[[UALocationService alloc] init] autorelease];
    STAssertTrue(120.00 == testService.minimumTimeBetweenForegroundUpdates, nil);
    STAssertFalse([UALocationService airshipLocationServiceEnabled], nil);
    STAssertEquals(testService.standardLocationDesiredAccuracy, kCLLocationAccuracyHundredMeters, nil);
    STAssertEquals(testService.standardLocationDistanceFilter, kCLLocationAccuracyHundredMeters, nil);
    STAssertEquals(testService.singleLocationBackgroundIdentifier, UIBackgroundTaskInvalid, nil);
}

- (void)setInitWithPurpose {
    STAssertTrue([locationService.purpose isEqualToString:@"TEST"],nil);
}

// Register user defaults only works on the first app run. Reset the values here to make sure
// they are read from user defaults. 
- (void)setTestValuesInNSUserDefaults {
    // UALocationService defaults. This needs to be kept in sync with the method in UAirship
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:[NSNumber numberWithBool:NO] forKey:UALocationServiceEnabledKey];
    [userDefaults setValue:@"TEST" forKey:UALocationServicePurposeKey];
    //kCLLocationAccuracyHundredMeters works, since it is also a double, this may change in future
    [userDefaults setValue:[NSNumber numberWithDouble:kCLLocationAccuracyHundredMeters] forKey:UAStandardLocationDistanceFilterKey];
    [userDefaults setValue:[NSNumber numberWithDouble:kCLLocationAccuracyHundredMeters] forKey:UAStandardLocationDesiredAccuracyKey];
}

//void (^theBlock)(NSInvocation *) = ^(NSInvocation *invocation) 
//{
//    NSString *value;
//    [invocation getArgument:&value atIndex:2];
//    value = [NSString stringWithFormat:@"MOCK %@", value];
//    [invocation setReturnValue:&value];
//};

#pragma mark -
#pragma mark Getters and Setters

// don't test the single location purpose, because it's transient and would not be changed once started

- (void)testMinimumTime {
    locationService.minimumTimeBetweenForegroundUpdates = 42.0;
    STAssertTrue(locationService.minimumTimeBetweenForegroundUpdates == 42.0,nil);
}
- (void)testSetPurpose {
    locationService.significantChangeProvider = [UASignificantChangeProvider providerWithDelegate:locationService];
    NSString* awsm = @"awesomeness";
    locationService.purpose = awsm;
    STAssertTrue([awsm isEqualToString:locationService.standardLocationProvider.purpose],nil);
    STAssertTrue([awsm isEqualToString:locationService.significantChangeProvider.purpose], nil);
    STAssertTrue(awsm == [[NSUserDefaults standardUserDefaults] valueForKey:UALocationServicePurposeKey],nil);
}

- (void)testStandardLocationGetSet {
    locationService.standardLocationDesiredAccuracy = 10.0;
    locationService.standardLocationDistanceFilter = 24.0;
    UAStandardLocationProvider *standard = locationService.standardLocationProvider;
    STAssertTrue(standard.distanceFilter == 24.0,nil);
    STAssertTrue(standard.desiredAccuracy == 10.0,nil);
    STAssertTrue(locationService.standardLocationDesiredAccuracy == 10.0,nil);
    STAssertTrue(locationService.standardLocationDistanceFilter == 24.0,nil);
}

- (void)testSignificantChangeGetSet {
    UASignificantChangeProvider *significant = [[[UASignificantChangeProvider alloc] initWithDelegate:nil] autorelease];
    locationService.significantChangeProvider = significant;
    STAssertEqualObjects(locationService, locationService.significantChangeProvider.delegate,nil);
}

- (void)testSingleLocationGetSet {
    locationService.singleLocationDesiredAccuracy = 42.0;
    locationService.timeoutForSingleLocationService = 100.0;
    STAssertEquals(42.0, [[NSUserDefaults standardUserDefaults] doubleForKey:UASingleLocationDesiredAccuracyKey], nil);
    STAssertEquals(100.0, [[NSUserDefaults standardUserDefaults] doubleForKey:UASingleLocationTimeoutKey], nil);
    STAssertEquals(42.0, locationService.singleLocationDesiredAccuracy, nil);
    STAssertEquals(100.0, locationService.timeoutForSingleLocationService, nil);
}

- (void)testCachedLocation {
    id mockLocation = [OCMockObject niceMockForClass:[CLLocationManager class]];
    locationService.standardLocationProvider.locationManager = mockLocation;
    [[mockLocation expect] location];
    [locationService location];
    [mockLocation verify];
}

#pragma mark NSUserDefaults class method access

- (void)testNSUserDefaultsMethods {
    NSString *cats = @"CATS_EVERYWHERE";
    NSString *catKey = @"Cat";
    [UALocationService setObject:cats forLocationServiceKey:catKey];
    NSString *back = [[NSUserDefaults standardUserDefaults] valueForKey:catKey];
    STAssertTrue([back isEqualToString:cats],nil);
    back = [UALocationService objectForLocationServiceKey:catKey];
    STAssertTrue([back isEqualToString:cats],nil);
    NSString *boolKey = @"I_LIKE_CATS";
    [UALocationService setBool:YES forLocationServiceKey:boolKey];
    BOOL boolBack = [[NSUserDefaults standardUserDefaults] boolForKey:boolKey];
    STAssertTrue(boolBack,nil);
    STAssertTrue([UALocationService boolForLocationServiceKey:boolKey],nil);
    double dbl = 42.0;
    NSString *dblKey = @"test_double_key";
    [UALocationService setDouble:dbl forLocationServiceKey:dblKey];
    STAssertTrue(dbl == [[NSUserDefaults standardUserDefaults] doubleForKey:dblKey],nil);
    STAssertTrue(dbl == [UALocationService doubleForLocationServiceKey:dblKey],nil);
    double answer = 42.0;
    [UALocationService setDouble:answer forLocationServiceKey:UASingleLocationDesiredAccuracyKey];
    [UALocationService setDouble:answer forLocationServiceKey:UAStandardLocationDesiredAccuracyKey];
    [UALocationService setDouble:answer forLocationServiceKey:UAStandardLocationDistanceFilterKey];
    STAssertEquals((CLLocationAccuracy)answer, [locationService desiredAccuracyForLocationServiceKey:UASingleLocationDesiredAccuracyKey], nil);
    STAssertEquals((CLLocationAccuracy)answer,[locationService desiredAccuracyForLocationServiceKey:UAStandardLocationDesiredAccuracyKey], nil);
}

#pragma mark Location Setters
- (void)testStandardLocationSetter {
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:nil] autorelease];
    locationService.standardLocationProvider = standard;
    STAssertEqualObjects(standard, locationService.standardLocationProvider, nil);
    STAssertEqualObjects(locationService.standardLocationProvider.delegate, locationService,nil);
    STAssertTrue(locationService.standardLocationDesiredAccuracy == locationService.standardLocationProvider.desiredAccuracy,nil);
    STAssertTrue(locationService.standardLocationDistanceFilter == locationService.standardLocationProvider.distanceFilter,nil);
}

- (void)testSignificantChangeSetter {
    UASignificantChangeProvider *significant = [[[UASignificantChangeProvider alloc] initWithDelegate:nil] autorelease];
    locationService.significantChangeProvider = significant;
    STAssertEqualObjects(significant, locationService.significantChangeProvider, nil);
    STAssertEqualObjects(locationService.significantChangeProvider.delegate, locationService,nil);
}   
 
#pragma mark -
#pragma mark Starting/Stopping Location Services 

#pragma mark  Standard Location
- (void)testStartReportingLocation {
    [[mockLocationService expect] startReportingLocationWithProvider:OCMOCK_ANY];
    locationService.standardLocationProvider = nil;
    [locationService startReportingStandardLocation];
    STAssertTrue([locationService.standardLocationProvider isKindOfClass:[UAStandardLocationProvider class]],nil);
    [mockLocationService verify];
}

- (void)testStopUpdatingLocation {
    UAStandardLocationProvider *standardDelegate = [[[UAStandardLocationProvider alloc] initWithDelegate:locationService] autorelease];
    locationService.standardLocationProvider = standardDelegate;
    id mockDelegate = [OCMockObject niceMockForClass:[CLLocationManager class]];
    standardDelegate.locationManager = mockDelegate;
    [[mockDelegate expect] stopUpdatingLocation];
    [locationService stopReportingStandardLocation];
    [mockDelegate verify];
    STAssertEquals(UALocationProviderNotUpdating, locationService.standardLocationServiceStatus, @"Service should not be updating");
}

- (void)testStandardLocationDidUpdateToLocation {
    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    locationService.delegate = mockDelegate;
    locationService.standardLocationDesiredAccuracy = 5.0;
    [[mockDelegate reject] locationService:OCMOCK_ANY didUpdateToLocation:OCMOCK_ANY fromLocation:OCMOCK_ANY];
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(54, 34) 
                                                         altitude:54 
                                               horizontalAccuracy:20 
                                                 verticalAccuracy:20 
                                                        timestamp:[NSDate date]];
    [locationService standardLocationDidUpdateToLocation:location fromLocation:[UALocationTestUtils testLocationPDX]];
    mockDelegate =  [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    locationService.delegate = mockDelegate;
    locationService.standardLocationDesiredAccuracy = 30.0;
    [[mockLocationService stub] reportLocationToAnalytics:OCMOCK_ANY fromProvider:OCMOCK_ANY];
    [[mockDelegate expect] locationService:OCMOCK_ANY didUpdateToLocation:location fromLocation:OCMOCK_ANY];
    [locationService standardLocationDidUpdateToLocation:location fromLocation:[UALocationTestUtils testLocationPDX]];
    [mockDelegate verify];
}

#pragma mark Significant Change Service
- (void)testStartMonitoringSignificantChanges {
    [[mockLocationService expect] startReportingLocationWithProvider:OCMOCK_ANY];
    [locationService startReportingSignificantLocationChanges];
    STAssertTrue([locationService.significantChangeProvider isKindOfClass:[UASignificantChangeProvider class]], nil);
    [mockLocationService verify];
}

- (void)testStopMonitoringSignificantChanges {
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    UASignificantChangeProvider *sigChangeDelegate = [[[UASignificantChangeProvider alloc] initWithDelegate:locationService] autorelease];
    locationService.significantChangeProvider = sigChangeDelegate;
    sigChangeDelegate.locationManager = mockLocationManager;
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [locationService stopReportingSignificantLocationChanges];
    [mockLocationManager verify];
    STAssertEquals(UALocationProviderNotUpdating, locationService.significantChangeServiceStatus, @"Sig change should not be updating");
}

- (void)testSignificantChangeDidUpdate {
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    [[mockLocationService expect] reportLocationToAnalytics:pdx fromProvider:OCMOCK_ANY];
    [locationService significantChangeDidUpdateToLocation:pdx fromLocation:[UALocationTestUtils testLocationSFO]];
    [mockLocationService verify];
}


#pragma mark -
#pragma mark CLLocationManager Authorization

- (void)testCLLocationManagerAuthorization {
    // Check just CoreLocation authorization
    [UALocationService setAirshipLocationServiceEnabled:YES];
    [self swizzleCLLocationClassEnabledAndAuthorized];
    STAssertTrue([UALocationService locationServicesEnabled],nil);
    STAssertTrue([UALocationService locationServiceAuthorized],nil);
    STAssertTrue([locationService isLocationServiceEnabledAndAuthorized], nil);
    STAssertFalse([UALocationService coreLocationWillPromptUserForPermissionToRun],nil);
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusDenied)];
    STAssertFalse([UALocationService locationServiceAuthorized],nil);
    STAssertFalse([locationService isLocationServiceEnabledAndAuthorized],nil);
    STAssertTrue([UALocationService coreLocationWillPromptUserForPermissionToRun],nil);
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusDenied) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnNO)];
    STAssertFalse([UALocationService locationServicesEnabled],nil);
    STAssertFalse([locationService isLocationServiceEnabledAndAuthorized],nil);
    STAssertTrue([UALocationService coreLocationWillPromptUserForPermissionToRun],nil);
    [self swizzleCLLocationClassMethod:@selector(returnNO) withMethod:@selector(locationServicesEnabled)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusRestricted)];
    STAssertFalse([UALocationService locationServiceAuthorized], nil);
    STAssertFalse([locationService isLocationServiceEnabledAndAuthorized],nil);
    STAssertTrue([UALocationService coreLocationWillPromptUserForPermissionToRun],nil);
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusRestricted) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusNotDetermined)];
    STAssertTrue([UALocationService locationServiceAuthorized], nil);
    STAssertTrue([locationService isLocationServiceEnabledAndAuthorized], nil);
    STAssertFalse([UALocationService coreLocationWillPromptUserForPermissionToRun],nil); 
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusNotDetermined) withMethod:@selector(authorizationStatus)];
}

- (void)testAirshipLocationAuthorization {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    [UALocationService setAirshipLocationServiceEnabled:NO];
    STAssertFalse([locationService isLocationServiceEnabledAndAuthorized], @"This should report NO when airship services are toggled off");
    [UALocationService setAirshipLocationServiceEnabled:YES];
    STAssertTrue([locationService isLocationServiceEnabledAndAuthorized], nil);
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
}

- (void)testForcePromptLocation {
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] isLocationServiceEnabledAndAuthorized];
    id mockProvider = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    [[mockProvider expect] startReportingLocation];
    locationService.promptUserForLocationServices = YES;
    [locationService startReportingLocationWithProvider:mockProvider];
    [mockLocationService verify];
    [mockProvider verify];
}

- (void)testLocationTimeoutError {
    locationService.bestAvailableSingleLocation = [UALocationTestUtils testLocationPDX];
    NSError *locationError = [locationService locationTimeoutError];
    STAssertTrue([UALocationServiceTimeoutError isEqualToString:locationError.domain], nil);
    STAssertTrue(UALocationServiceTimedOut == locationError.code, nil);
    STAssertEquals(locationService.bestAvailableSingleLocation, 
                   [[locationError userInfo] objectForKey:UALocationServiceBestAvailableSingleLocationKey ], nil);
}


#pragma mark -
#pragma mark Single Location Service

/* Test the single location provider starts with a given provider, and
 sets the status appropriately. Also tests that the service starts and
 lazy loads a location manager */
- (void)testReportCurrentLocationStarts{
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:nil] autorelease];
    id mockProvider = [OCMockObject partialMockForObject:standard];
    locationService.singleLocationProvider = standard;
    STAssertEqualObjects(locationService, locationService.singleLocationProvider.delegate, nil);
    // Nil the delegate, it should be reset when the service is started
    locationService.singleLocationProvider.delegate = nil;
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] isLocationServiceEnabledAndAuthorized];
    [[mockProvider expect] startReportingLocation];
    [locationService reportCurrentLocation];
    STAssertEqualObjects(locationService, locationService.singleLocationProvider.delegate, nil);
    [mockLocationService verify];
    [mockProvider verify];
    
}

- (void)testReportCurrentLocationWontStartUnauthorized {
    locationService.singleLocationProvider = nil;
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] isLocationServiceEnabledAndAuthorized];
    [locationService reportCurrentLocation];
    [mockLocationService verify];
    //This depends on the lazy loading working correctly
    STAssertNil(locationService.singleLocationProvider, nil);
}

/* Tests that the single location service won't start when already updating */
- (void)testAcquireSingleLocationWontStartWhenUpdating {
    // Make sure location services are authorized
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] isLocationServiceEnabledAndAuthorized];
    id mockProvider = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    UALocationProviderStatus updating = UALocationProviderUpdating;
    [[[mockProvider stub] andReturnValue:OCMOCK_VALUE(updating)] serviceStatus];
    locationService.singleLocationProvider = mockProvider;
    [[mockProvider reject] startReportingLocation];
    [locationService reportCurrentLocation];
}

/* Accuracy calculations */
- (void)testSingleLocationDidUpdateToLocation {
    locationService.singleLocationDesiredAccuracy = 10.0;
    locationService.singleLocationProvider = [[[UAStandardLocationProvider alloc] initWithDelegate:locationService] autorelease];
    id mockDelegate = [OCMockObject niceMockForProtocol:@protocol(UALocationServiceDelegate)];
    locationService.delegate = mockDelegate;
    // Test that the location service is stopped when a good location is received.
    CLLocation *pdx = [[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(50, 50) altitude:100.0 horizontalAccuracy:5 verticalAccuracy:5 timestamp:[NSDate date]] autorelease];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
    [[mockDelegate expect] locationService:locationService didUpdateToLocation:pdx fromLocation:sfo];
    [[mockLocationService expect] stopSingleLocationWithLocation:pdx];
    [locationService singleLocationDidUpdateToLocation:pdx fromLocation:sfo];
    [mockDelegate verify];
    // Test that location that is not accurate enough does not stop the location service
    pdx = [[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(50, 50) altitude:100.0 horizontalAccuracy:12.0 verticalAccuracy:5 timestamp:[NSDate date]] autorelease];
    [[mockLocationService reject] stopSingleLocationWithLocation:OCMOCK_ANY];
    [locationService singleLocationDidUpdateToLocation:pdx fromLocation:sfo];
    STAssertEquals(pdx, locationService.bestAvailableSingleLocation, nil);
}

/* Test that the single location service won't start if a valid location has been 
 received in the past 120 seconds. This important for the automatic single location service,
 multitasking, and the fact that the single location service is run as a background task
 */
// Verifies that the service stops after receiving a valid location
// and that an analytics call is made

- (void)testSingleLocationWontStartBeforeMinimumTimeBetweenLocations {
    locationService.minimumTimeBetweenForegroundUpdates = 500;
    locationService.dateOfLastLocation = [NSDate date];
    locationService.automaticLocationOnForegroundEnabled = YES;
    [[mockLocationService reject] reportCurrentLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
}

// Only test that that the method call is made to start the service
- (void)testSingleLocationStartsOnAppForeground {
    locationService.minimumTimeBetweenForegroundUpdates = 0;
    locationService.dateOfLastLocation = [NSDate date];
    locationService.automaticLocationOnForegroundEnabled = YES;  
    [[mockLocationService expect] reportCurrentLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify]; 
}

// Lightweight tests for method calls only
- (void)testStopSingleLocationWithLocation {
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    locationService.singleLocationProvider = [UAStandardLocationProvider providerWithDelegate:locationService];
    [[mockLocationService expect] reportLocationToAnalytics:pdx fromProvider:locationService.singleLocationProvider];
    [[mockLocationService expect] stopSingleLocation];
    [locationService stopSingleLocationWithLocation:pdx];
    [mockLocationService verify];
}

// Lightweight tests for method calls only
- (void)testStopSingleLocationWithError {
    // Setup comparisions
    id mockLocationDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
    NSError* error = [locationService locationTimeoutError];
    __block UALocationService* service = nil;
    __block NSError* locationError = nil;
    void (^argBlock)(NSInvocation*) = ^(NSInvocation* invocation) {
        [invocation getArgument:&service atIndex:2];
        [invocation getArgument:&locationError atIndex:3];
    };
    //
    [[[mockLocationDelegate expect] andDo:argBlock] locationService:locationService didFailWithError:OCMOCK_ANY];
    locationService.singleLocationProvider = [UAStandardLocationProvider providerWithDelegate:locationService];
    locationService.bestAvailableSingleLocation = [UALocationTestUtils testLocationPDX];
    [[mockLocationDelegate expect] locationService:locationService didUpdateToLocation:locationService.bestAvailableSingleLocation fromLocation:nil];
    locationService.delegate = mockLocationDelegate;
    [[mockLocationService expect] reportLocationToAnalytics:locationService.bestAvailableSingleLocation fromProvider:locationService.singleLocationProvider];
    [[mockLocationService expect] stopSingleLocation];
    [locationService stopSingleLocationWithError:error];
    STAssertEqualObjects(error, locationError, nil);
    STAssertEqualObjects(service, locationService, nil);
    STAssertTrue([locationError.domain isEqualToString:UALocationServiceTimeoutError], nil);
}


#pragma mark -
#pragma mark Location Service Provider start/restart BOOLS

- (void)testStartRestartBooleansOnProviders {
    id mockStandard = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    id mockSignificant = [OCMockObject niceMockForClass:[UASignificantChangeProvider class]];
    // Setting this to YES is a quick way to get the startReportingLocationWithProvider: method to 
    // allow the location service to be started. 
    locationService.promptUserForLocationServices = YES;
    //
    locationService.standardLocationProvider = mockStandard;
    locationService.significantChangeProvider = mockSignificant;
    [locationService startReportingStandardLocation];
    STAssertTrue(locationService.shouldStartReportingStandardLocation, nil);
    [locationService startReportingSignificantLocationChanges];
    STAssertTrue(locationService.shouldStartReportingSignificantChange, nil);
    [locationService stopReportingStandardLocation];
    STAssertFalse(locationService.shouldStartReportingStandardLocation, nil);
    [locationService stopReportingSignificantLocationChanges];
    STAssertFalse(locationService.shouldStartReportingSignificantChange, nil);
}

#pragma mark -
#pragma mark Automatic Location Update on Foreground

- (void)testAutomaticLocationOnForegroundEnabledCallsReportCurrentLocation {
    id mockStandard = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    locationService.automaticLocationOnForegroundEnabled = NO;
    locationService.singleLocationProvider = mockStandard;
    [[mockLocationService expect] reportCurrentLocation];
    locationService.automaticLocationOnForegroundEnabled = YES;
    [mockLocationService verify];
    [[mockLocationService reject] reportCurrentLocation];
    locationService.automaticLocationOnForegroundEnabled = YES;
}

- (void)testAutomaticLocationUpdateOnForegroundShouldUpdateCases {
    // setting automatic location on foreground has the side effect of
    // calling reportCurrentLocation
    [[mockLocationService expect] reportCurrentLocation];
    locationService.automaticLocationOnForegroundEnabled = YES;
    [mockLocationService verify];
    [[mockLocationService expect] reportCurrentLocation];
    // Setup a date over 120.0 seconds ago
    NSDate *dateOver120 = [[[NSDate alloc] initWithTimeInterval:-121.0 sinceDate:[NSDate date]] autorelease];
    locationService.dateOfLastLocation = dateOver120;
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
}

- (void)testAutomaticLocationOnForegroundShouldNotUpdateCases {
    locationService.automaticLocationOnForegroundEnabled = NO;
    [[mockLocationService reject] reportCurrentLocation];
    // If there is another call to acquireSingleLocaitonAndUpload, this will fail
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    locationService.dateOfLastLocation = [NSDate date];
    [[mockLocationService reject] reportCurrentLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]]; 
    UALocationService *localService = [[[UALocationService alloc] initWithPurpose:@"test"] autorelease];
    id localMockService = [OCMockObject partialMockForObject:localService];
    localService.automaticLocationOnForegroundEnabled = YES;
    // setup a date for the current time
    localService.dateOfLastLocation = [NSDate date];
    [[localMockService reject] reportCurrentLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
}

- (void)testShouldPerformAutoLocationUpdate {
    locationService.automaticLocationOnForegroundEnabled = NO;
    STAssertFalse([locationService shouldPerformAutoLocationUpdate],nil);
    locationService.automaticLocationOnForegroundEnabled = YES;
    locationService.dateOfLastLocation = nil;
    STAssertTrue([locationService shouldPerformAutoLocationUpdate],nil);
    locationService.dateOfLastLocation = [NSDate dateWithTimeIntervalSinceNow:-121.0];
    STAssertTrue([locationService shouldPerformAutoLocationUpdate],nil);
    locationService.dateOfLastLocation = [NSDate dateWithTimeIntervalSinceNow:-90.0];
    STAssertFalse([locationService shouldPerformAutoLocationUpdate],nil);
    
}

#pragma mark -
#pragma mark Restarting Location service on startup

- (void)testStopLocationServiceWhenBackgroundNotEnabledAndAppEntersBackground {
    locationService.backgroundLocationServiceEnabled = NO;
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] isLocationServiceEnabledAndAuthorized];
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] isLocationServiceEnabledAndAuthorized];
    [locationService startReportingStandardLocation];
    [locationService startReportingSignificantLocationChanges];
    [[[mockLocationService expect] andForwardToRealObject] stopReportingStandardLocation];
    [[[mockLocationService expect] andForwardToRealObject] stopReportingSignificantLocationChanges];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
}

- (void)testLocationServicesNotStoppedOnAppBackgroundWhenEnabled {
    locationService.backgroundLocationServiceEnabled = YES;
    [[mockLocationService reject] stopReportingStandardLocation];
    [[mockLocationService reject] stopReportingSignificantLocationChanges];
    [[[mockLocationService expect] andForwardToRealObject] appDidEnterBackground];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
    STAssertFalse([UALocationService boolForLocationServiceKey:@"standardLocationServiceStatusRestart"], nil);
    STAssertFalse([UALocationService boolForLocationServiceKey:@"significantChangeServiceStatusRestart"], nil);
}

// If background services are enabled, they do not need to be restarted on foreground events
- (void)testLocationServicesNotStartedWhenBackgroundServicesEnabled {
    locationService.backgroundLocationServiceEnabled = YES;
    [[mockLocationService reject] startReportingStandardLocation];
    [[mockLocationService reject] startReportingSignificantLocationChanges];
    [[[mockLocationService expect] andForwardToRealObject] appWillEnterForeground];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
    
}

// When background location services are not enabled, they need to be restarted on app foreground
- (void)testStartLocationServiceOnAppForegroundWhenBackgroundServicesNotEnabled {
    // location services can't be started without authorization, and since objects are lazy loaded
    // skip starting and just add them manually. 
    locationService.standardLocationProvider = [UAStandardLocationProvider providerWithDelegate:locationService];
    locationService.significantChangeProvider = [UASignificantChangeProvider providerWithDelegate:locationService];
    // Setup booleans as if location services were started previously
    locationService.shouldStartReportingStandardLocation = YES;
    locationService.shouldStartReportingSignificantChange = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    // Setup proper expectations for app foreground
    [[[mockLocationService expect] andForwardToRealObject] startReportingStandardLocation];
    [[[mockLocationService expect] andForwardToRealObject] startReportingSignificantLocationChanges];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
    // Check that distanceFilter and desiredAccuracy match whatever is in NSUserDefaults at this point
    CLLocationAccuracy accuracy = [[NSUserDefaults standardUserDefaults] doubleForKey:UAStandardLocationDesiredAccuracyKey];
    CLLocationDistance distance = [[NSUserDefaults standardUserDefaults] doubleForKey:UAStandardLocationDistanceFilterKey];
    // The location values returned by the UALocationService come directly off the CLLocationManager object
    STAssertEquals(accuracy, locationService.standardLocationDesiredAccuracy, nil);
    STAssertEquals(distance, locationService.standardLocationDistanceFilter, nil);
}

// When services arent running, and backround is not enabled, restart values are set to NO
- (void)testBackgroundServiceValuesAreFalse {
    locationService.backgroundLocationServiceEnabled = NO;
    locationService.standardLocationProvider.serviceStatus = UALocationProviderNotUpdating;
    locationService.significantChangeProvider = [UASignificantChangeProvider providerWithDelegate:locationService];
    locationService.significantChangeProvider.serviceStatus = UALocationProviderNotUpdating;
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    STAssertFalse(locationService.shouldStartReportingStandardLocation ,nil);
    STAssertFalse(locationService.shouldStartReportingSignificantChange ,nil);
    [[mockLocationService reject] startReportingStandardLocation];
    [[mockLocationService reject] startReportingSignificantLocationChanges];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
}

#pragma mark -
#pragma mark UALocationProvider Delegate callbacks

- (void)testDidFailWithErrorAndDidChangeAuthorization {
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
    locationService.delegate = mockDelegate;
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:locationService];
    locationService.standardLocationProvider = standard;
    [[mockDelegate expect] locationService:locationService didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [standard.delegate locationProvider:standard withLocationManager:standard.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockDelegate verify];
    NSError *locationError = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
    [[mockDelegate expect] locationService:locationService didFailWithError:locationError];
    [standard.delegate locationProvider:standard withLocationManager:standard.locationManager didFailWithError:locationError];
    [mockDelegate verify];
    NSError *error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorNetwork userInfo:nil];
    [[mockDelegate expect] locationService:locationService didFailWithError:error];
    [standard.delegate locationProvider:standard withLocationManager:standard.locationManager didFailWithError:error];
    [mockDelegate verify];
    STAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UADeprecatedLocationAuthorizationKey], @"deprecated key should return NO");
}

// Don't test all the delegate calls, they are covered well elsewhere 
- (void)didFailWithNetworkError {
    id mockLocationProvider = [OCMockObject mockForProtocol:@protocol(UALocationProviderProtocol)];
    [[mockLocationProvider expect] stopReportingLocation];
    CLLocationManager *placeholder = [[[CLLocationManager alloc] init] autorelease];
    [locationService locationProvider:mockLocationProvider withLocationManager:placeholder didFailWithError:[NSError errorWithDomain:kCLErrorDomain code:kCLErrorNetwork userInfo:nil]];
    [mockLocationProvider verify];
}


- (void)testUpdateToNewLocation {
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
    locationService.significantChangeProvider = [[[UASignificantChangeProvider alloc] initWithDelegate:locationService] autorelease];
    locationService.singleLocationProvider = [[[UAStandardLocationProvider alloc] initWithDelegate:locationService] autorelease];
    [[mockLocationService expect] singleLocationDidUpdateToLocation:pdx fromLocation:sfo];
    [[mockLocationService expect] standardLocationDidUpdateToLocation:pdx fromLocation:sfo];
    [[mockLocationService expect] significantChangeDidUpdateToLocation:pdx fromLocation:sfo];
    [locationService.standardLocationProvider.delegate locationProvider:locationService.standardLocationProvider 
                                                    withLocationManager:locationService.standardLocationProvider.locationManager 
                                                      didUpdateLocation:pdx 
                                                           fromLocation:sfo];
    [locationService.singleLocationProvider.delegate locationProvider:locationService.singleLocationProvider 
                                                  withLocationManager:locationService.singleLocationProvider.locationManager 
                                                    didUpdateLocation:pdx 
                                                         fromLocation:sfo];
    [locationService.significantChangeProvider.delegate locationProvider:locationService.significantChangeProvider 
                                                     withLocationManager:locationService.significantChangeProvider.locationManager 
                                                       didUpdateLocation:pdx 
                                                            fromLocation:sfo];
    [mockLocationService verify];
}

#pragma mark -
#pragma mark Support Methods -> Swizzling

// Don't forget to unswizzle the swizzles in cases of strange behavior
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector {
    NSError *swizzleError = nil;
    [CLLocationManager jr_swizzleClassMethod:oneSelector withClassMethod:anotherSelector error:&swizzleError];
    STAssertNil(swizzleError, @"Method swizzling for CLLocationManager failed with error %@", swizzleError.description);
}
- (void)swizzleUALocationServiceClassMethod:(SEL)oneMethod withMethod:(SEL)anotherMethod {
    NSError *swizzleError = nil;
    [UALocationService jr_swizzleClassMethod:oneMethod withClassMethod:anotherMethod error:&swizzleError];
    STAssertNil(swizzleError,@"Method swizzling for UALocationService failed with error %@", swizzleError.description);
}

- (void)swizzleCLLocationClassEnabledAndAuthorized {
    NSError *locationServicesSizzleError = nil;
    NSError *authorizationStatusSwizzleError = nil;
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnYES)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusAuthorized)];    
    STAssertNil(locationServicesSizzleError, @"Error swizzling locationServicesCall on CLLocation error %@", locationServicesSizzleError.description);
    STAssertNil(authorizationStatusSwizzleError, @"Error swizzling authorizationStatus on CLLocation error %@", authorizationStatusSwizzleError.description);
    STAssertTrue([CLLocationManager locationServicesEnabled], @"This should be swizzled to YES");
    STAssertEquals(kCLAuthorizationStatusAuthorized, [CLLocationManager authorizationStatus], @"this should be kCLAuthorizationStatusAuthorized" );
}

- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized {
    NSError *locationServicesSizzleError = nil;
    NSError *authorizationStatusSwizzleError = nil;
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusAuthorized) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(returnYES) withMethod:@selector(locationServicesEnabled)];
    STAssertNil(locationServicesSizzleError, @"Error unsizzling locationServicesCall on CLLocation error %@", locationServicesSizzleError.description);
    STAssertNil(authorizationStatusSwizzleError, @"Error unswizzling authorizationStatus on CLLocation error %@", authorizationStatusSwizzleError.description);
}

#pragma mark -
#pragma mark Deprecated Location Methods


- (void)testdeprecatedLocationAuthorization {
    STAssertFalse([UALocationService useDeprecatedMethods], nil);
    [self swizzleUALocationServiceClassMethod:@selector(useDeprecatedMethods) withMethod:@selector(returnYES)];
    // The above swizzle should force code execution throgh the deprecated methods.
    STAssertEquals([UALocationService locationServicesEnabled], [CLLocationManager locationServicesEnabled], @"This should call the class and instance method of CLLocationManager, should be equal");
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UADeprecatedLocationAuthorizationKey];
    STAssertTrue([UALocationService locationServiceAuthorized], @"This should be YES, it's read out of NSUserDefaults");
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UADeprecatedLocationAuthorizationKey];
    STAssertFalse([UALocationService locationServiceAuthorized], @"Thir should report NO, read out of NSUserDefaults");
    // On first run of the app, this key should be nil, and we want a value of authorized for that since the user 
    // has not been asked about location
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:UADeprecatedLocationAuthorizationKey];
    STAssertTrue([UALocationService locationServiceAuthorized], nil);
    [self swizzleUALocationServiceClassMethod:@selector(returnYES) withMethod:@selector(useDeprecatedMethods)];
}

@end
