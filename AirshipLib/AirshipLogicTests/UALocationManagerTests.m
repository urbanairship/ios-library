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

@interface UALocationManagerTests : SenTestCase {
    UALocationManager *testLocationManager_;
    CLLocation *testLocationOne_;
    CLLocation *testLocationTwo_;
}
- (void) swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
- (void)swizzleCLLocationClassEnabledAndAuthorized;
- (void)swizzleCLlocationClassBackFromEnabledAndAuthorized;
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
- (void)testGetSetMethods {
    CLLocationDistance testDistance = 100.0;
    testLocationManager_.distanceFilter = testDistance;
    // Check the distance from the CLLocationManager directly
    STAssertEquals(testDistance, testLocationManager_.locationManager.distanceFilter, @"distanceFilter setter broken");
    STAssertEquals(testDistance, testLocationManager_.distanceFilter, @"distanceFilter getter broken");
    // CLLocationAccuracy best is the default, don't use that
    CLLocationAccuracy testAccuracy = kCLLocationAccuracyHundredMeters;
    testLocationManager_.desiredAccuracy = testAccuracy;
    STAssertEquals(testAccuracy, testLocationManager_.locationManager.desiredAccuracy, @"Desired accuracy setter broken");
    STAssertEquals(testAccuracy, testLocationManager_.desiredAccuracy, @"Desired accuracy getter broken");
}

- (void)testStartUpdatingLocationWhenLocationIsEnabledAndAuthorized {
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnYES)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusAuthorized)];
    STAssertEquals(kCLAuthorizationStatusAuthorized, [CLLocationManager authorizationStatus], @"authoriztionStatus swizzling failed");
    STAssertEquals(YES, [CLLocationManager locationServicesEnabled], @"locationServices not enabled");
    //Setup the mock object and expected messages
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    [(CLLocationManager*)[mockLocationManager expect] startUpdatingLocation];
    testLocationManager_.locationManager = mockLocationManager;
    BOOL locationStart = [testLocationManager_ startUpdatingLocation];
    [mockLocationManager verify];
    UALocationManagerActivityStatus managerStatus = testLocationManager_.locationManagerActivityStatus;
    STAssertEquals(UALocationManagerUpdating, managerStatus, @"testLocationManager status is not set properly");
    STAssertTrue(locationStart, @"[testLocationManager startUpdatingLocation] should return YES");
    [self swizzleCLLocationClassMethod:@selector(returnYES) withMethod:@selector(locationServicesEnabled)];
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusAuthorized) withMethod:@selector(authorizationStatus)];
}

- (void)testStartUpdatingLocationWhenLocationIsDisabled {
    // setup and test swizzle
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnNO)];
    STAssertEquals(NO, [CLLocationManager locationServicesEnabled], @"CLLocationManager should return NO");
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    testLocationManager_.locationManager = mockLocationManager;
    // Mock objects that receive messages that are not stubbed or expected will throw an exception
    STAssertNoThrow([testLocationManager_ startUpdatingLocation], @"Exception thown in testLocationManager, CLLocationManager object should not receive any messages");
    UALocationManagerActivityStatus managerStatus = testLocationManager_.locationManagerActivityStatus;
    STAssertEquals(UALocationManagerNotUpdating, managerStatus, @"testLocationManager status is not set properly");
    STAssertFalse([testLocationManager_ startUpdatingLocation], @"testLocationManager startUpdatingLocation should return NO");
    [self swizzleCLLocationClassMethod:@selector(returnNO) withMethod:@selector(locationServicesEnabled)];
}

- (void)testStartUpdatingLocationWhenLocationIsEnabledAndNotAuthorized {
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusDenied)];
    CLAuthorizationStatus status = kCLAuthorizationStatusDenied;
    STAssertEquals(kCLAuthorizationStatusDenied, status, @"CLLocationManger should return kCLAuthorizationStatusDenied (2) but returned %d", status);
    id mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];
    testLocationManager_.locationManager = mockLocationManager;
    STAssertNoThrow([testLocationManager_ startUpdatingLocation], @"UALocationManager should not send a message to CLLocationManager instance, and no exception should be thown");
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusDenied) withMethod:@selector(authorizationStatus)];
}

- (void)testStopUpdatingLocation {
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] setDelegate:testLocationManager_];
    [[mockLocationManager expect] stopUpdatingLocation];
    testLocationManager_.locationManager = mockLocationManager;
    [testLocationManager_ stopUpdatingLocation];
    [mockLocationManager verify];
                              
}

- (void)testAuthorizationStatusChangeDelegateCall {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    [testLocationManager_ startUpdatingLocation];
    STAssertEquals(UALocationManagerUpdating, testLocationManager_.locationManagerActivityStatus, @"locationManagerActivityStatus status should be UALocationManagerUpdating");
    id partialLocationMock = [OCMockObject partialMockForObject:testLocationManager_.locationManager];
    [[partialLocationMock expect] stopUpdatingLocation];
    [testLocationManager_.locationManager sendAuthorizationChangedDelegateCallWithAuthorization:kCLAuthorizationStatusDenied];
    [partialLocationMock verify];
    STAssertEquals(UALocationManagerNotUpdating, testLocationManager_.locationManagerActivityStatus, @"locationManagerActivityStatus should be UALocationManagerNotUpdating");
    [self swizzleCLlocationClassBackFromEnabledAndAuthorized];
    
}

- (void)testLocationDidFailWithErrorDelegateCall {
    NSError* testError = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    [testLocationManager_.locationManager sendLocationDidFailWithErrorDelegateCallWithError:testError];
    STAssertEqualObjects(testError, testLocationManager_.locationManagerError, @"locationManagerError not set correctly");
}

- (void)testDidUpdateToLocationFromLocationDelegateCall {
    [self setUpTestLocations];
    [testLocationManager_.locationManager sendDidUpdateToLocation:testLocationOne_ fromLocation:testLocationTwo_];
    STAssertEqualObjects(testLocationOne_, testLocationManager_.lastReportedLocation, @"Location was not successfuly set in UALocationManager after didUpdate delegate call");
    [self tearDownTestLocations];
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

- (void)swizzleCLlocationClassBackFromEnabledAndAuthorized {
    NSError *locationServicesSizzleError = nil;
    NSError *authorizationStatusSwizzleError = nil;
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusAuthorized) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(returnYES) withMethod:@selector(locationServicesEnabled)];
    STAssertNil(locationServicesSizzleError, @"Error unsizzling locationServicesCall on CLLocation error %@", locationServicesSizzleError.description);
    STAssertNil(authorizationStatusSwizzleError, @"Error unswizzling authorizationStatus on CLLocation error %@", authorizationStatusSwizzleError.description);
}

@end
