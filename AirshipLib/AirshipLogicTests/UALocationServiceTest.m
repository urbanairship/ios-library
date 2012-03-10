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
#import "UALocationService_Private.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"
#import "UALocationTestUtils.h"
#import "JRSwizzle.h"
#import <SenTestingKit/SenTestingKit.h>


@interface UALocationServiceTest : SenTestCase
{
    UALocationService *locationService;
    id mockLocationService; //[OCMockObject partialMockForObject:locationService]
    BOOL yes; // use for OCMockValue(val)
    BOOL no; // use for OCMockValue(val)
}
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
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

// TODO: change the default settings after preliminary developmet is done for desiredAccuracy and distanceFilter
- (void)testBasicInit{
    [self setTestValuesInNSUserDefaults];
    NSDictionary* userDefaults = [[NSUserDefaults standardUserDefaults] dictionaryForKey:UALocationServicePreferences];
    UALocationService *basic = [[[UALocationService alloc] init] autorelease];
    STAssertTrue([userDefaults isEqualToDictionary:basic.locationServiceValues], @"Location service values should match what's on disk");
    UALocationService *service = [[[UALocationService alloc] initWithPurpose:@"test"] autorelease];
    STAssertTrue([@"test" isEqualToString:service.purpose],nil);
    STAssertNotNil(service.standardLocationProvider, nil);
}


- (void)testUALocationServiceUpdatesValuesOnInit {
    [self setTestValuesInNSUserDefaults];
    [self swizzleCLLocationClassEnabledAndAuthorized];
    UALocationService *localService = [[[UALocationService alloc] initWithPurpose:@"CATS"] autorelease];
    STAssertTrue(localService.locationServiceAllowed, @"Default is NO, CLLManager swizzled to YES, updated value should be YES");
    STAssertFalse(localService.locationServiceEnabled, @"Default val is NO, value should now be YES");
    STAssertTrue([localService.purpose isEqualToString:@"CATS"], nil);
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
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

#pragma mark Location Setters
- (void)testStandardLocationSetter {
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:nil] autorelease];
    id mockStandard = [OCMockObject partialMockForObject:standard];
    [[[mockStandard expect] andForwardToRealObject] setDelegate:locationService];
    [[[mockStandard expect] andForwardToRealObject] setPurpose:locationService.purpose];
    [[[mockStandard expect] andForwardToRealObject] setDistanceFilter:locationService.standardLocationDistanceFilter];
    [[[mockStandard expect] andForwardToRealObject] setDesiredAccuracy:locationService.standardLocationDesiredAccuracy];
    locationService.standardLocationProvider = standard;
    [mockStandard verify];
    STAssertEqualObjects(standard, locationService.standardLocationProvider, nil);
}

- (void)testSignificantChangeSetter {
    UASignificantChangeProvider *significant = [[[UASignificantChangeProvider alloc] initWithDelegate:nil] autorelease];
    id mockSignificant = [OCMockObject partialMockForObject:significant];
    [[[mockSignificant expect] andForwardToRealObject] setDelegate:locationService];
    [[[mockSignificant expect] andForwardToRealObject] setPurpose:locationService.purpose];
    locationService.significantChangeProvider = significant;
    [mockSignificant verify];
    STAssertEqualObjects(significant, locationService.significantChangeProvider, nil);
}



#pragma mark -
#pragma mark lastLocationAndDate

- (void)testLastLocationAndDate {
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
    [[mockLocationService stub] sendLocationToAnalytics:pdx fromProvider:locationService.standardLocationProvider];
    [locationService.standardLocationProvider.delegate UALocationProvider:locationService.standardLocationProvider 
                                                      withLocationManager:locationService.standardLocationProvider.locationManager 
                                                        didUpdateLocation:pdx 
                                                             fromLocation:sfo];
    STAssertEqualObjects(pdx, locationService.lastReportedLocation, nil);
    NSTimeInterval smallAmountOfTime = [locationService.dateOfLastReport timeIntervalSinceNow];
    STAssertEqualsWithAccuracy(smallAmountOfTime, 0.001, 0.005, nil);
}

#pragma mark -
#pragma mark locationServiceSettings Key Value Observing 

- (void)setTestValuesInNSUserDefaults {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:3];
    [dictionary setValue:[NSNumber numberWithBool:NO] forKey:uaLocationServiceEnabledKey];
    [dictionary setValue:[NSNumber numberWithBool:NO] forKey:uaLocationServiceAllowedKey];
    [dictionary setValue:@"CATS" forKey:uaLocationServicePurposeKey];
    [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:UALocationServicePreferences];
}

- (void)testKeyValueObserving {
    // Stub out KVO callbacks
    [[mockLocationService expect] observeValueForKeyPath:uaLocationServiceEnabledKey ofObject:locationService.locationServiceValues change:[OCMArg any] context:[OCMArg anyPointer]];
    [[mockLocationService expect] observeValueForKeyPath:uaLocationServiceAllowedKey ofObject:locationService.locationServiceValues change:[OCMArg any] context:[OCMArg anyPointer]];
    [[mockLocationService expect] observeValueForKeyPath:uaLocationServicePurposeKey ofObject:locationService.locationServiceValues change:[OCMArg any] context:[OCMArg anyPointer]];
    // Trigger all the appropriate callbacks
    [locationService setLocationServiceEnabled:YES];
    [locationService setLocationServiceAllowed:YES];
    [locationService setPurpose:@"CATS"];
    [mockLocationService verify];
}


//- (void)testGetSetLocationServiceValues {
//    locationService.purpose = @"CATS";
//    STAssertTrue([locationService.purpose isEqualToString:@"CATS"],nil);
//    locationService.locationServiceAllowed = YES;
//    STAssertTrue(locationService.locationServiceAllowed, nil);
//    locationService.locationServiceEnabled = YES;
//    STAssertTrue(locationService.locationServiceEnabled, nil);
//    [locationService setValue:@"SuperCat" forLocationServiceKey:@"TESTCAT"];
//    STAssertTrue([@"SuperCat" isEqualToString:(NSString*)[locationService valueForLocationServiceKey:@"TESTCAT"]], nil);
//}

#pragma mark -
#pragma mark Starting/Stopping Location Services 
#pragma mark  Standard Location
- (void)testStartUpdatingLocation {
    UAStandardLocationProvider *standardProvider = [[UAStandardLocationProvider alloc] initWithDelegate:locationService];
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] startUpdatingLocation];
    standardProvider.locationManager = mockLocationManager;
    locationService.standardLocationProvider = standardProvider;
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceAllowed];
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceEnabled];
    [locationService startReportingLocation];
    [mockLocationManager verify];
    [mockLocationService verify];
    STAssertEquals(UALocationProviderUpdating, locationService.standardLocationServiceStatus, @"Service status should be updating");
}

- (void)testStopUpdatingLocation {
    UAStandardLocationProvider *standardDelegate = [[[UAStandardLocationProvider alloc] initWithDelegate:locationService] autorelease];
    locationService.standardLocationProvider = standardDelegate;
    id mockDelegate = [OCMockObject niceMockForClass:[CLLocationManager class]];
    standardDelegate.locationManager = mockDelegate;
    [[mockDelegate expect] stopUpdatingLocation];
    [locationService stopReportingLocation];
    [mockDelegate verify];
    STAssertEquals(UALocationProviderNotUpdating, locationService.standardLocationServiceStatus, @"Service should not be updating");
}

//#pragma mark Significant Change Service
- (void)testStartMonitoringSignificantChanges {
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceEnabled];
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceAllowed];
    UASignificantChangeProvider *sigChangeProvider = [[[UASignificantChangeProvider alloc] initWithDelegate:locationService] autorelease];
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    sigChangeProvider.locationManager = mockLocationManager;
    [[mockLocationManager expect] startMonitoringSignificantLocationChanges];
    locationService.significantChangeProvider = sigChangeProvider;
    [locationService startReportingSignificantLocationChanges];
    [mockLocationService verify];
    [mockLocationManager verify];
    STAssertEquals(locationService.significantChangeServiceStatus, UALocationProviderUpdating, @"Sig change should be updating");                              
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
//
//#pragma mark Standard Location when not enabled
- (void)testStandardLocationServicesWillNotStartWhenNotEnabled {
    // Services will not start if UALocationServiceAllowed || UALocationServiceEnabled returns NO
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] locationServiceEnabled];
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceAllowed];
    id mockLocationProvider = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    // Fail if startProvidingLocation is called
    [[mockLocationProvider reject] startReportingLocation];
    locationService.standardLocationProvider = mockLocationProvider;
    [locationService startReportingLocation];
    [mockLocationService verify];
    // The service should short circuit before asking for locationServiceEnabled
    [[mockLocationService reject] locationServiceEnabled];
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] locationServiceAllowed];
    [locationService startReportingLocation];
    [mockLocationService verify];
}

//#pragma mark Significant Change when not enabled
- (void)testSignificantChangeServicesWillNotStartWhenNotEnabled {
    // Services will not start if UALocationServiceAllowed || UALocationServiceEnabled returns NO
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] locationServiceEnabled];
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceAllowed];
    id mockLocationProvider = [OCMockObject niceMockForClass:[UASignificantChangeProvider class]];
    // Fail if startProvidingLocation is called
    [[mockLocationProvider reject] startReportingLocation];
    locationService.significantChangeProvider = mockLocationProvider;
    [locationService startReportingSignificantLocationChanges];
    [mockLocationService verify];
    // Don't set an expectation for both values to be called here, UALocationServiceAllowed set to NO
    // short circuits statment evaluation. An explicit rejection makes debugging easier
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] locationServiceAllowed];
    [[mockLocationService reject] locationServiceEnabled];
    [locationService startReportingSignificantLocationChanges];
    [mockLocationService verify];
}

//#pragma mark Single Location when not enabled
- (void)testSingleLocationServiceWillNotStartWhenNotEnabled {
    // Services will not start if UALocationServiceAllowed || UALocationServiceEnabled returns NO
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] locationServiceEnabled];
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceAllowed];
    id mockLocationProvider = [OCMockObject niceMockForClass:[UAStandardLocationProvider class]];
    // Fail if startProvidingLocation is called
    [[mockLocationProvider reject] startReportingLocation];
    locationService.singleLocationProvider = mockLocationProvider;
    [locationService reportCurrentLocation];
    [mockLocationService verify];
    // Don't set an expectation for both values to be called here, UALocationServiceAllowed set to NO
    // short circuits statment evaluation
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(no)] locationServiceAllowed];
    [locationService reportCurrentLocation];
    [mockLocationService verify];
}

#pragma mark -
#pragma mark CLLocationManager Authorization

- (void)testCLLocationManagerAuthorization {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    BOOL authorized = [locationService isLocationServiceEnabledAndAuthorized];
    STAssertTrue(authorized, @"This method should return true when services are enabled and authorized");
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusDenied)];
    authorized = [locationService isLocationServiceEnabledAndAuthorized];
    STAssertFalse(authorized, @"This method should return false when not authorized");
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusDenied) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnNO)];
    authorized = [locationService isLocationServiceEnabledAndAuthorized];
    STAssertFalse(authorized, @"This method should return false when not enabled");
    [self swizzleCLLocationClassMethod:@selector(returnNO) withMethod:@selector(locationServicesEnabled)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusRestricted)];
    authorized = [locationService isLocationServiceEnabledAndAuthorized];
    STAssertFalse(authorized, @"This method should return false when authorizationStatus is kCLAuthorizationStatusRestricted");
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusRestricted) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusNotDetermined)];
    authorized = [locationService isLocationServiceEnabledAndAuthorized];
    STAssertTrue(authorized, @"This method should return true when authorizationStatus is kCLAuthorizationStatusNotDetermined");
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusNotDetermined) withMethod:@selector(authorizationStatus)];
}

- (void)testDepricatedEnabledAndAuthorized {
    locationService.deprecatedLocation = YES;
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] init] autorelease];
    locationService.standardLocationProvider = standard;
    id mockProvider = [OCMockObject partialMockForObject:standard.locationManager];
    [[[mockProvider expect] andReturnValue:OCMOCK_VALUE(yes)] locationServicesEnabled];
    locationService.locationServiceAllowed = YES;
    // enabled YES authorized YES
    STAssertTrue([locationService isLocationServiceEnabledAndAuthorized], nil);
    [mockProvider verify];
    [[[mockProvider expect] andReturnValue:OCMOCK_VALUE(yes)] locationServicesEnabled];
    locationService.locationServiceAllowed = NO;
    // enabled YES authorized NO
    STAssertFalse([locationService isLocationServiceEnabledAndAuthorized], nil);
    [mockProvider verify];
    // Change the mock object and reset stubbed method
    standard = [[[UAStandardLocationProvider alloc] init] autorelease];
    mockProvider = [OCMockObject partialMockForObject:standard.locationManager];
    [[[mockProvider expect] andReturnValue:OCMOCK_VALUE(no)] locationServicesEnabled];
    locationService.standardLocationProvider = standard;
    // enabled NO authorized NO
    STAssertFalse([locationService isLocationServiceEnabledAndAuthorized], nil);
    [mockProvider verify];
    [[[mockProvider expect] andReturnValue:OCMOCK_VALUE(no)] locationServicesEnabled];
    // enabled NO authorized YES
    locationService.locationServiceAllowed = YES;
    STAssertFalse([locationService isLocationServiceEnabledAndAuthorized], nil);
    [mockProvider verify];
}

#pragma mark -
#pragma mark UALocationServiceAllowed
// Testing these methods
// - (void)updateLocationServiceStatus:(UALocationProviderStatus)status forProvider:(id<UALocationProviderProtocol>)provider;
// - (void)updateAllowedStatus:(CLAuthorizationStatus)status

- (void)testUpdateAllowedStatus {
    locationService.locationServiceAllowed = YES;
    [locationService updateAllowedStatus:kCLAuthorizationStatusDenied];
    STAssertFalse(locationService.locationServiceAllowed, nil);
    locationService.locationServiceAllowed = YES;
    [locationService updateAllowedStatus:kCLAuthorizationStatusRestricted];
    STAssertFalse(locationService.locationServiceAllowed, nil);
    [locationService updateAllowedStatus:kCLAuthorizationStatusAuthorized];
    STAssertTrue(locationService.locationServiceAllowed, nil);
    locationService.locationServiceAllowed = NO;
    [locationService updateAllowedStatus:kCLAuthorizationStatusNotDetermined];
    STAssertTrue(locationService.locationServiceAllowed, nil);    
    
}

#pragma mark -
#pragma mark Single Location Service

- (void)testReportCurrentLocation{
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] initWithDelegate:locationService] autorelease];
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    standard.locationManager = mockLocationManager;
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceAllowed];
    [[[mockLocationService expect] andReturnValue:OCMOCK_VALUE(yes)] locationServiceEnabled];
    [[mockLocationManager expect] startUpdatingLocation];
    locationService.singleLocationProvider = standard;
    [locationService reportCurrentLocation];
    [mockLocationService verify];
    [mockLocationManager verify];
    STAssertEquals(UALocationProviderUpdating, locationService.singleLocationServiceStatus, @"Single location service should be running");
    // Test the ability to get a pointer to the singleLocationProvider from the single location service
    // while it is running
    STAssertEqualObjects(locationService.singleLocationProvider, standard, nil);
}

// singleLocation should not attempt to start again while updating
- (void)testAcquireSingleLocationWhenServiceReportsUpdating {
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:locationService];
    locationService.singleLocationProvider = standard;
    standard.locationManager = mockLocationManager;
    [locationService reportCurrentLocation];
    //This will fail if any method is called on mockLocationManager
}


// Verifies that the service stops after receiving a valid location
// and that an analytics call is made
- (void)testAcquireSingleLocationServiceShutdown {
    CLLocation *PDX = [UALocationTestUtils testLocationPDX];
    CLLocation *SFO = [UALocationTestUtils testLocationSFO];
    UAStandardLocationProvider *provider = [UAStandardLocationProvider providerWithDelegate:locationService];
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] stopUpdatingLocation]; 
    provider.locationManager = mockLocationManager;
    locationService.singleLocationProvider = provider;
    [[mockLocationService expect] sendLocationToAnalytics:SFO fromProvider:provider];
    [provider.delegate UALocationProvider:provider withLocationManager:provider.locationManager didUpdateLocation:SFO fromLocation:PDX];
    [mockLocationManager verify];
    [mockLocationService verify];
    
}

#pragma mark -
#pragma mark Automatic Location Update on Foreground

-(void)testAutomaticLocationUpdateOnForeground {
    locationService.automaticLocationOnForegroundEnabled = YES;
    [[mockLocationService expect] reportCurrentLocation];
    // Setup a date over 120.0 seconds ago
    NSDate *dateOver120 = [[[NSDate alloc] initWithTimeInterval:-121.0 sinceDate:[NSDate date]] autorelease];
    locationService.dateOfLastReport = dateOver120;
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
    locationService.automaticLocationOnForegroundEnabled = NO;
    [[mockLocationService reject] reportCurrentLocation];
    // If there is another call to acquireSingleLocaitonAndUpload, this will fail
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    // reset the time stamp to now, should not trigger an update
    locationService.automaticLocationOnForegroundEnabled = YES;
    locationService.dateOfLastReport = [NSDate date];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]]; 
}

#pragma mark -
#pragma mark Restarting Location service on startup
//
- (void)testStopLocationServiceWhenBackgroundNotEnabledAndAppEntersBackground {
    locationService.backgroundLocationServiceEnabled = NO;
    locationService.locationServiceAllowed = YES;
    [self swizzleCLLocationClassEnabledAndAuthorized];
    [locationService startReportingLocation];
    [locationService startReportingSignificantLocationChanges];
    [[[mockLocationService expect] andForwardToRealObject] stopReportingLocation];
    [[[mockLocationService expect] andForwardToRealObject] stopReportingSignificantLocationChanges];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
}
//
- (void)testLocationServicesNotStoppedOnAppBackgroundWhenEnabled {
    locationService.backgroundLocationServiceEnabled = YES;
    [[mockLocationService reject] stopReportingLocation];
    [[mockLocationService reject] stopReportingSignificantLocationChanges];
    [[[mockLocationService expect] andForwardToRealObject] appDidEnterBackground];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
    STAssertFalse([locationService boolForLocationServiceKey:@"standardLocationServiceStatusRestart"], nil);
    STAssertFalse([locationService boolForLocationServiceKey:@"significantChangeServiceStatusRestart"], nil);
}

- (void)testLocationServicesNotStartedWhenBackgroundServicesEnabled {
    locationService.backgroundLocationServiceEnabled = YES;
    [[mockLocationService reject] startReportingLocation];
    [[mockLocationService reject] startReportingSignificantLocationChanges];
    [[[mockLocationService expect] andForwardToRealObject] appWillEnterForeground];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [mockLocationService verify];
    
}

- (void)testStartLocationServiceOnAppForegroundWhenBackgroundServicesNotEnabled {
    // location services can't be started without authorization, and since objects are lazy loaded
    // skip starting and just add them manually. 
    locationService.standardLocationProvider = [UAStandardLocationProvider providerWithDelegate:locationService];
    locationService.significantChangeProvider = [UASignificantChangeProvider providerWithDelegate:locationService];
    // setup the correct status
    locationService.standardLocationProvider.serviceStatus = UALocationProviderUpdating;
    locationService.significantChangeProvider.serviceStatus = UALocationProviderUpdating;
    // Make the class perform backgrounding tasks
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [[[mockLocationService expect] andForwardToRealObject] startReportingLocation];
    [[[mockLocationService expect] andForwardToRealObject] startReportingSignificantLocationChanges];
    // Setup proper expectations for app foreground
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
    [[mockDelegate expect] UALocationService:locationService didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [standard.delegate UALocationProvider:standard withLocationManager:standard.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [mockDelegate verify];
    NSError *locationError = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
    [[mockDelegate expect] UALocationService:locationService didFailWithError:locationError];
    [standard.delegate UALocationProvider:standard withLocationManager:standard.locationManager didFailWithError:locationError];
    [mockDelegate verify];
}


- (void)testUpdateToNewLocation {
    UAStandardLocationProvider *standard = [[[UAStandardLocationProvider alloc] init] autorelease];
    locationService.standardLocationProvider = standard;
    CLLocation *pdx = [UALocationTestUtils testLocationPDX];
    CLLocation *sfo = [UALocationTestUtils testLocationSFO];
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
    locationService.delegate = mockDelegate;
    [[mockDelegate expect] UALocationService:locationService didUpdateToLocation:pdx fromLocation:sfo];
    [[mockLocationService expect] sendLocationToAnalytics:pdx fromProvider:standard];
    [standard.delegate UALocationProvider:standard withLocationManager:standard.locationManager didUpdateLocation:pdx fromLocation:sfo];
    [mockLocationService verify];
    [mockDelegate verify];
    STAssertEquals(locationService.lastReportedLocation, pdx, nil);
}

#pragma mark -
#pragma mark Support Methods -> Swizzling

// Don't forget to unswizzle the swizzles in cases of strange behavior
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector {
    NSError *swizzleError = nil;
    [CLLocationManager jr_swizzleClassMethod:oneSelector withClassMethod:anotherSelector error:&swizzleError];
    STAssertNil(swizzleError, @"Method swizzling for CLLocationManager failed with error %@", swizzleError.description);
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



@end
