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

- (void)testCachedLocation {
    id mockLocation = [OCMockObject niceMockForClass:[CLLocationManager class]];
    locationService.standardLocationProvider.locationManager = mockLocation;
    [[mockLocation expect] location];
    [locationService location];
    [mockLocation verify];
}

#pragma mark Standard Location distanceFilter desiredAccuracy NSUserDefaults


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
#pragma mark lastLocationAndDate

//- (void)testLastLocationAndDate {
//    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
//    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
//    [[mockLocationService stub] reportLocationToAnalytics:pdx fromProvider:locationService.standardLocationProvider];
//    [locationService.standardLocationProvider.delegate locationProvider:locationService.standardLocationProvider 
//                                                      withLocationManager:locationService.standardLocationProvider.locationManager 
//                                                        didUpdateLocation:pdx 
//                                                             fromLocation:sfo];
//    STAssertEqualObjects(pdx, locationService.lastReportedLocation, nil);
//    NSTimeInterval smallAmountOfTime = [locationService.dateOfLastLocation timeIntervalSinceNow];
//    STAssertEqualsWithAccuracy(smallAmountOfTime, 0.001, 0.005, nil);
//}
 
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


#pragma mark -
#pragma mark Single Location Service

/* Test the single location provider starts with a given provider, and
 sets the status appropriately. Also tests that the service starts and
 lazy loads a location manager */
- (void)testReportCurrentLocationStartsAndSetsStatus{
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:locationService] autorelease];
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    standard.locationManager = mockLocationManager;
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] isLocationServiceEnabledAndAuthorized];
    [[mockLocationManager expect] startUpdatingLocation];
    locationService.singleLocationProvider = standard;
    [locationService reportCurrentLocation];
    [mockLocationService verify];
    [mockLocationManager verify];
    STAssertEquals(UALocationProviderUpdating, locationService.singleLocationServiceStatus, @"Single location service should be running");
    // Test the ability to get a pointer to the singleLocationProvider from the single location service
    // while it is running
    STAssertEqualObjects(locationService.singleLocationProvider, standard, nil);
    // redo the test to make sure it runs with a nil provider
    locationService.singleLocationProvider = nil;
    [[mockLocationService expect] startReportingLocationWithProvider:OCMOCK_ANY];
    [locationService reportCurrentLocation];
    [mockLocationService verify];
}

/* Tests that the single location service won't start when already updating */
- (void)testAcquireSingleLocationWhenServiceReportsUpdating {
    // Make sure location services are authorized
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] isLocationServiceEnabledAndAuthorized];
    // Explicitly rejected methods will cause niceMocks to fail
    [[mockLocationService reject] startReportingLocationWithProvider:OCMOCK_ANY];
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:locationService];
    // Setup the service status to updating
    standard.serviceStatus = UALocationProviderUpdating;
    locationService.singleLocationProvider = standard;
    [locationService reportCurrentLocation];
}

/* Test that the single location service won't start if a valid location has been 
 received in the past 120 seconds. This important for the automatic single location service,
 multitasking, and the fact that the single location service is run as a background task
 */

//// Verifies that the service stops after receiving a valid location
//// and that an analytics call is made
//- (void)testAcquireSingleLocationServiceShutdown {
//    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
//    CLLocation *SFO = [UALocationTestUtils testLocationSFO];
//    UAStandardLocationProvider *provider = [UAStandardLocationProvider providerWithDelegate:locationService];
//    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
//    [[mockLocationManager expect] stopUpdatingLocation]; 
//    provider.locationManager = mockLocationManager;
//    locationService.singleLocationProvider = provider;
//    [[mockLocationService expect] reportLocationToAnalytics:SFO fromProvider:provider];
//    [provider.delegate locationProvider:provider withLocationManager:provider.locationManager didUpdateLocation:SFO fromLocation:PDX];
//    [mockLocationManager verify];
//    [mockLocationService verify];
//}

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

-(void)testAutomaticLocationUpdateOnForeground {
    locationService.automaticLocationOnForegroundEnabled = YES;
    [[mockLocationService expect] reportCurrentLocation];
    // Setup a date over 120.0 seconds ago
    NSDate *dateOver120 = [[[NSDate alloc] initWithTimeInterval:-121.0 sinceDate:[NSDate date]] autorelease];
    locationService.dateOfLastLocation = dateOver120;
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
    locationService.automaticLocationOnForegroundEnabled = NO;
    [[mockLocationService reject] reportCurrentLocation];
    // If there is another call to acquireSingleLocaitonAndUpload, this will fail
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    // reset the time stamp to now, should not trigger an update
    locationService.automaticLocationOnForegroundEnabled = YES;
    locationService.dateOfLastLocation = [NSDate date];
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

// Some of these background/foreground tests are probably redundant, and should be refactored
//- (void)testStartStopServicesThroughForegroundBackgroundEvents {
//    id mockStandard = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
//    id mockSignificant = [OCMockObject niceMockForClass:[UASignificantChangeProvider class]];
//    locationService.standardLocationProvider = mockStandard;
//    locationService.significantChangeProvider = mockSignificant;
//    // Guarantee location starts without mocking authorization
//    locationService.promptUserForLocationServices = YES;
//}

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

- (void)testSingleLocationShutsDownOnAppBackground {
    UAStandardLocationProvider *single = [UAStandardLocationProvider providerWithDelegate:locationService];
    single.serviceStatus = UALocationProviderUpdating;
    locationService.singleLocationProvider = single;
    id mockSingle = [OCMockObject partialMockForObject:single];
    [[mockSingle expect] stopReportingLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [mockSingle verify];
    [[mockSingle reject] stopReportingLocation];
    single.serviceStatus = UALocationProviderNotUpdating;
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
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


//- (void)testUpdateToNewLocation {
//    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] init] autorelease];
//    locationService.standardLocationProvider = standard;
//    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
//    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
//    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
//    locationService.delegate = mockDelegate;
//    [[mockDelegate expect] locationService:locationService didUpdateToLocation:pdx fromLocation:sfo];
//    [[mockLocationService expect] reportLocationToAnalytics:pdx fromProvider:standard];
//    [standard.delegate locationProvider:standard withLocationManager:standard.locationManager didUpdateLocation:pdx fromLocation:sfo];
//    [mockLocationService verify];
//    [mockDelegate verify];
//    STAssertEquals(locationService.lastReportedLocation, pdx, nil);
//}

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
