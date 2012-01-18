//
//  UALocationManagerTests.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/6/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UALocationManager.h"
#import "JRSwizzle.h"
#import "UAGlobal.h"
#import "CLLocationManager+Test.h"

/** Test Categories
 *  These categories open up private methods for the purposes of 
 *  manipulating the environment for testing
 */

#pragma mark -
#pragma UALocationManager Test categories
@interface UALocationManager (Test)

- (void)setLocationManager:(CLLocationManager*)locationManger;
- (void)setDelegate:(id<UALocationServicesDelegate>)delegate; 

@end

@implementation UALocationManager (Test)
- (void)setLocationManager:(CLLocationManager *)locationManager {
    locationManager_.delegate = nil;
    [locationManager_ autorelease];
    locationManager_ = [locationManager retain];
    locationManager_.delegate = self;
}

- (void)setDelegate:(id<UALocationServicesDelegate>)delegate {
    delegate_ = delegate;
}

@end

/** Test cases */

@interface UALocationManagerTests : SenTestCase {
    UALocationManager *testLocationManager_;
    CLLocation *testLocationOne_;
    CLLocation *testLocationTwo_;
    CLLocationDistance testDistance_; 
    CLLocationAccuracy testAccuracy_;

}
// Swizzling
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
- (void)swizzleCLLocationClassEnabledAndAuthorized;
- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized;
// Setup/Teardown methods that don't need to be run for every test case
- (void)setUpTestLocations;
- (void)tearDownTestLocations;
@end

@implementation UALocationManagerTests

#pragma mark -
#pragma Setup/Teardown
- (void)setUp {
    testLocationManager_ = [[UALocationManager alloc] initWithDelegateOrNil:nil];
    STAssertNotNil(testLocationManager_, @"location manager is nil!");
}

- (void)tearDown {
    [testLocationManager_ release];
    testLocationManager_ = nil;

}

- (void)setupTestDistanceAndAccuracy {
    testDistance_ = 100.0;
    // CLLocationAccuracy best is the default, don't use that
    testAccuracy_ = kCLLocationAccuracyHundredMeters;
}

- (void)setUpTestLocations {
    CLLocationCoordinate2D coord1 = CLLocationCoordinate2DMake(45.525352839897, -122.682115697712);
    CLLocationCoordinate2D coord2 = CLLocationCoordinate2DMake(37.7726834626323, -122.406178648848);
    testLocationOne_ = [[CLLocation alloc] initWithCoordinate:coord1 altitude:100.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
    testLocationTwo_ = [[CLLocation alloc] initWithCoordinate:coord2 altitude:100.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
    STAssertNotNil(testLocationOne_, @"location allocation fail");
    STAssertNotNil(testLocationTwo_, @"location allocaiton fail");
}

- (void)tearDownTestLocations {
    [testLocationOne_ release];
    testLocationOne_ = nil; 
    [testLocationTwo_ release];
    testLocationTwo_ = nil;
}

#pragma mark -
#pragma Testing Methods



// Only testing get/set methods since they are being forwarded and retrieved from a different object
- (void)testGetSetMethodsForStandardLocationManager {
    [self setupTestDistanceAndAccuracy];
    // Check the distance from the CLLocationManager directly
    testLocationManager_.desiredAccuracy = testAccuracy_;
    testLocationManager_.distanceFilter = testDistance_;
    //Test the CLLocationManager directly
    NSString *distanceFilterTag = @"distanceFilter";
    NSString *desiredAccuracyTag = @"desiredAccuracy";
    STAssertEquals(testDistance_, testLocationManager_.locationManager.distanceFilter, @"%@ setter broken", distanceFilterTag);
    STAssertEquals(testDistance_, testLocationManager_.distanceFilter, @"%@ getter broken", distanceFilterTag);
    STAssertEquals(testAccuracy_, testLocationManager_.locationManager.desiredAccuracy, @"%@ setter broken", desiredAccuracyTag);
    STAssertEquals(testAccuracy_, testLocationManager_.desiredAccuracy, @"%@ getter broken", desiredAccuracyTag);
}

#pragma mark -
#pragma Test start/stop services and authorization/enabled states

- (void)testStartUpdatingStandardLocationWhenEnabledAndAuthorized {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    STAssertEquals(kCLAuthorizationStatusAuthorized, [CLLocationManager authorizationStatus], @"authorizationStatus swizzling failed");
    STAssertEquals(YES, [CLLocationManager locationServicesEnabled], @"locationServices not enabled");
    //Setup the mock object and expected messages
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    [(CLLocationManager*)[mockLocationManager expect] startUpdatingLocation];
    testLocationManager_.locationManager = mockLocationManager;
    BOOL locationStart = [testLocationManager_ startStandardLocationUpdates];
    [mockLocationManager verify];
    UALocationManagerServiceActivityStatus managerStatus = testLocationManager_.standardLocationActivityStatus;
    STAssertEquals(UALocationServiceUpdating, managerStatus, @"testLocationManager status is not set properly");
    STAssertTrue(locationStart, @"[testLocationManager startUpdatingLocation] should return YES");
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
}

- (void)testStartUpdatingLocationWhenLocationIsDisabled {
    // setup and test swizzle
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnNO)];
    STAssertEquals(NO, [CLLocationManager locationServicesEnabled], @"CLLocationManager should return NO");
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    testLocationManager_.locationManager = mockLocationManager;
    // Mock objects that receive messages that are not stubbed or expected will throw an exception
    STAssertNoThrow([testLocationManager_ startStandardLocationUpdates], @"Exception thown in testLocationManager, CLLocationManager object should not receive any messages");
    UALocationManagerServiceActivityStatus managerStatus = testLocationManager_.standardLocationActivityStatus;
    STAssertEquals(UALocationServiceNotUpdating, managerStatus, @"testLocationManager status is not set properly");
    STAssertFalse([testLocationManager_ startStandardLocationUpdates], @"testLocationManager startUpdatingLocation should return NO");
    [self swizzleCLLocationClassMethod:@selector(returnNO) withMethod:@selector(locationServicesEnabled)];
}

- (void)testStartUpdatingLocationWhenLocationIsEnabledAndNotAuthorized {
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusDenied)];
    CLAuthorizationStatus status = kCLAuthorizationStatusDenied;
    STAssertEquals(kCLAuthorizationStatusDenied, status, @"CLLocationManger should return kCLAuthorizationStatusDenied (2) but returned %d", status);
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    testLocationManager_.locationManager = mockLocationManager;
    STAssertNoThrow([testLocationManager_ startStandardLocationUpdates], @"UALocationManager should not send a message to CLLocationManager instance, and no exception should be thown");
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusDenied) withMethod:@selector(authorizationStatus)];
}

- (void)testStopStandardLocationUpdates {
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    [[mockLocationManager expect] stopUpdatingLocation];
    testLocationManager_.locationManager = mockLocationManager;
    [testLocationManager_ stopStandardLocationUpdates];
    [mockLocationManager verify];  
}

- (void)testStartSignificantChangeServiceWhenEnabledAndAuthorized {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    testLocationManager_.locationManager = mockLocationManager;
    [[mockLocationManager expect] startMonitoringSignificantLocationChanges];
    [testLocationManager_ startSignificantChangeLocationUpdates];
    [mockLocationManager verify]; 
    STAssertEquals(testLocationManager_.significantChangeActivityStatus, UALocationServiceUpdating, @"significantChangeLocationService should be UALocationServiceUpdating");
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
}

- (void)testStartSignificantChangeServiceWhenLocationIsDisabled {
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnNO)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusAuthorized)];
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    testLocationManager_.locationManager = mockLocationManager;
    [testLocationManager_ startSignificantChangeLocationUpdates];
    STAssertEquals(testLocationManager_.significantChangeActivityStatus, UALocationServiceNotUpdating, @"significantChangeServiceStatus should be UAServiceStatusNotUpdating");
    [self swizzleCLLocationClassMethod:@selector(returnNO) withMethod:@selector(locationServicesEnabled)];
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusAuthorized) withMethod:@selector(authorizationStatus)];
}

- (void)testStartSignificantChangeServiceWhenLocationIsEnabledAndNotAuthorized {
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnYES)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusDenied)];
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    testLocationManager_.locationManager = mockLocationManager;
    [testLocationManager_ startSignificantChangeLocationUpdates];
    STAssertEquals(testLocationManager_.significantChangeActivityStatus, UALocationServiceNotUpdating, @"significantChangeServiceStatus should be UAServiceStatusNotUpdating");
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusDenied) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(returnYES) withMethod:@selector(locationServicesEnabled)];
}

- (void)testStopSignificantChangeLocationService {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    testLocationManager_.locationManager = mockLocationManager;
    [[mockLocationManager expect] startMonitoringSignificantLocationChanges];
    [testLocationManager_ startSignificantChangeLocationUpdates];
    STAssertEquals(testLocationManager_.significantChangeActivityStatus, UALocationServiceUpdating, @"significantChangeActivityStatus should be UALocationServiceUpdating");
    [[mockLocationManager expect] stopMonitoringSignificantLocationChanges];
    [testLocationManager_ stopSignificantChangeLocationUpdates];
    STAssertEquals(testLocationManager_.significantChangeActivityStatus, UALocationServiceNotUpdating, @"significantChangeActivityStatust should be UALocationServiceNotUpdating");
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];                          
}


#pragma mark -
#pragma CLLocationManager delegate callbacks

- (void)testAuthorizationStatusChangeDelegateCall {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    [testLocationManager_ startStandardLocationUpdates];
    STAssertEquals(UALocationServiceUpdating, testLocationManager_.standardLocationActivityStatus, @"locationManagerActivityStatus status should be UALocationServiceUpdating");
    id partialLocationMock = [OCMockObject partialMockForObject:testLocationManager_.locationManager];
    [[partialLocationMock expect] stopUpdatingLocation];
    [testLocationManager_.locationManager sendAuthorizationChangedDelegateCallWithAuthorization:kCLAuthorizationStatusDenied];
    [partialLocationMock verify];
    STAssertEquals(UALocationServiceNotUpdating, testLocationManager_.standardLocationActivityStatus, @"locationManagerActivityStatus should be UALocationServiceNotUpdating");
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
    
}

- (void)testLocationDidFailWithErrorDelegateCall {
    NSError* testError = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    STAssertNil(testLocationManager_.delegate, @"testLocationManager.delegate should be nil");
    STAssertNoThrow([testLocationManager_.locationManager sendLocationDidFailWithErrorDelegateCallWithError:testError], @"Nothing should crash with a nil delegate");
    id testDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServicesDelegate)];
    testLocationManager_.delegate = testDelegate; 
    [[testDelegate expect] uaLocationManager:testLocationManager_ locationManager:[OCMArg isNotNil] didFailWithError:testError];
    [testLocationManager_.locationManager sendLocationDidFailWithErrorDelegateCallWithError:testError];
    [testDelegate verify];
}

- (void)testDidUpdateToLocationFromLocationDelegateCall {
    [self setUpTestLocations];
    [testLocationManager_.locationManager sendDidUpdateToLocation:testLocationOne_ fromLocation:testLocationTwo_];
    STAssertEqualObjects(testLocationOne_, testLocationManager_.lastReportedLocation, @"Location was not successfuly set in UALocationManager after didUpdate delegate call");
    [self tearDownTestLocations];
}

- (void)testUIApplicationDidEnterBackgroundNotificationStopsStandardLocationMonitoringIfNotEnabled {
    id mockLocationManager = [OCMockObject partialMockForObject:testLocationManager_.locationManager];
    [[mockLocationManager stub] startUpdatingLocation];
    [[mockLocationManager stub] stopUpdatingLocation];
    [testLocationManager_ startStandardLocationUpdates];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [mockLocationManager verify];
}

- (void)testUIApplicationDidEnterBackgroundNotifcationStopsSignificantChangeLocationMonitoringIfNotEnabled {
    id mockLocationManager = [OCMockObject partialMockForObject:testLocationManager_.locationManager];
    [[mockLocationManager stub] startUpdatingLocation];
    [[mockLocationManager stub] stopUpdatingLocation];
    [testLocationManager_ startSignificantChangeLocationUpdates];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [mockLocationManager verify];
}



#pragma mark -
#pragma Support Methods

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
