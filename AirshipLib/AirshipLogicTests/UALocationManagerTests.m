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

@interface CLLocationManager (Test)
+ (BOOL)returnYES;
+ (BOOL)returnNO;
+ (CLAuthorizationStatus)returnCLLocationStatusAuthorized;
+ (CLAuthorizationStatus)returnCLLocationStatusDenied;
- (void)sendAuthorizationChangedDelegateCallWithAuthorization:(CLAuthorizationStatus)status;
- (void)sendLocationDidFailWithErrorDelegateCallWithError:(NSError*)error;
- (void)sendDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation;
@end
// Add methods to CLLocationManager for swizzling
@implementation CLLocationManager (Test)
+ (BOOL)returnYES {
    return YES;
}
+ (BOOL)returnNO {
    return NO;
}
+ (CLAuthorizationStatus)returnCLLocationStatusAuthorized {
    return  kCLAuthorizationStatusAuthorized;
}
+ (CLAuthorizationStatus)returnCLLocationStatusDenied {
    return kCLAuthorizationStatusDenied;
}
- (void)sendAuthorizationChangedDelegateCallWithAuthorization:(CLAuthorizationStatus)status {
    [self.delegate locationManager:self didChangeAuthorizationStatus:status];
}

- (void)sendLocationDidFailWithErrorDelegateCallWithError:(NSError*)error {
    [self.delegate locationManager:self didFailWithError:error];
}

- (void)sendDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation {
    [self.delegate locationManager:self didUpdateToLocation:newLocation fromLocation:oldLocation];
}
@end

@interface UALocationManager (Test)

- (void)setLocationManager:(CLLocationManager*)locationManger;
@end

@implementation UALocationManager (Test)
- (void)setLocationManager:(CLLocationManager *)locationManager {
    locationManager_.delegate = nil;
    [locationManager_ autorelease];
    locationManager_ = [locationManager retain];
    locationManager_.delegate = self;
}

@end

@interface UALocationManagerTests : SenTestCase {
    UALocationManager *testLocationManager_;
    CLLocation *testLocationOne_;
    CLLocation *testLocationTwo_;
    CLLocationDistance testDistance_; 
    CLLocationAccuracy testAccuracy_;

}
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
- (void)swizzleCLLocationClassEnabledAndAuthorized;
- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized;
- (void)setUpTestLocations;
- (void)tearDownTestLocations;
@end

@implementation UALocationManagerTests

#pragma mark -
#pragma Setup/Teardown
- (void)setUp {
    testLocationManager_ = [[UALocationManager alloc] init];
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
    testLocationManager_.desiredAccuracyForStandardLocationService = testAccuracy_;
    testLocationManager_.distanceFilterForStandardLocationService = testDistance_;
    //Test the CLLocationManager directly
    NSString *distanceFilterTag = @"distanceFilterForStandardLocation";
    NSString *desiredAccuracyTag = @"desiredAccuracyForStandardLocation";
    STAssertEquals(testDistance_, testLocationManager_.locationManager.distanceFilter, @"%@ setter broken", distanceFilterTag);
    STAssertEquals(testDistance_, testLocationManager_.distanceFilterForStandardLocationService, @"%@ getter broken", distanceFilterTag);
    STAssertEquals(testAccuracy_, testLocationManager_.locationManager.desiredAccuracy, @"%@ setter broken", desiredAccuracyTag);
    STAssertEquals(testAccuracy_, testLocationManager_.desiredAccuracyForStandardLocationService, @"%@ getter broken", desiredAccuracyTag);
}

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
    UALocationManagerActivityStatus managerStatus = testLocationManager_.locationManagerActivityStatus;
    STAssertEquals(UALocationManagerUpdating, managerStatus, @"testLocationManager status is not set properly");
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
    UALocationManagerActivityStatus managerStatus = testLocationManager_.locationManagerActivityStatus;
    STAssertEquals(UALocationManagerNotUpdating, managerStatus, @"testLocationManager status is not set properly");
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

//- (void)testAuthorizationStatusChangeDelegateCall {
//    [self swizzleCLLocationClassEnabledAndAuthorized];
//    [testLocationManager_ startStandardLocationUpdates];
//    STAssertEquals(UALocationManagerUpdating, testLocationManager_.locationManagerActivityStatus, @"locationManagerActivityStatus status should be UALocationManagerUpdating");
//    id partialLocationMock = [OCMockObject partialMockForObject:testLocationManager_.locationManager];
//    [[partialLocationMock expect] stopUpdatingLocation];
//    [testLocationManager_.locationManager sendAuthorizationChangedDelegateCallWithAuthorization:kCLAuthorizationStatusDenied];
//    [partialLocationMock verify];
//    STAssertEquals(UALocationManagerNotUpdating, testLocationManager_.locationManagerActivityStatus, @"locationManagerActivityStatus should be UALocationManagerNotUpdating");
//    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
//    
//}

//- (void)testLocationDidFailWithErrorDelegateCall {
//    NSError* testError = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
//    [testLocationManager_.locationManager sendLocationDidFailWithErrorDelegateCallWithError:testError];
//    STAssertEqualObjects(testError, testLocationManager_.locationManagerError, @"locationManagerError not set correctly");
//}
//
//- (void)testDidUpdateToLocationFromLocationDelegateCall {
//    [self setUpTestLocations];
//    [testLocationManager_.locationManager sendDidUpdateToLocation:testLocationOne_ fromLocation:testLocationTwo_];
//    STAssertEqualObjects(testLocationOne_, testLocationManager_.lastReportedLocation, @"Location was not successfuly set in UALocationManager after didUpdate delegate call");
//    [self tearDownTestLocations];
//}


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
