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
- (void)sendChangeAuthorizationStatusCallToDelegate;
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
    CLAuthorizationStatus authorized = kCLAuthorizationStatusAuthorized;
    return authorized;
}
+ (CLAuthorizationStatus)returnCLLocationStatusDenied {
    CLAuthorizationStatus denied = kCLAuthorizationStatusDenied;
    return denied;
}
- (void)sendChangeAuthorizationCallToDelegateWithAuthrization:(CLAuthorizationStatus)status {
    [self.delegate locationManager:self didChangeAuthorizationStatus:status];
}

@end


@interface UALocationManagerTests : SenTestCase {
    UALocationManager *testLocationManager_;
}
- (void) swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
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
    //Swizzle methods
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnYES)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusAuthorized)];
    STAssertEquals(kCLAuthorizationStatusAuthorized, [CLLocationManager authorizationStatus], @"authoriztionStatus swizzling failed");
    STAssertEquals(YES, [CLLocationManager locationServicesEnabled], @"locationServices not enabled");
    //Setup the mock object and expected messages
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] startUpdatingLocation];
    testLocationManager_.locationManager = mockLocationManager;
    [testLocationManager_ startUpdatingLocation];
    [mockLocationManager verify];
    UALocationManagerStatus managerStatus = testLocationManager_.currentStatus;
    STAssertEquals(UALocationManagerUpdating, managerStatus, @"testLocationManager status is not set properly");
}

- (void)testStartUpdatingLocationWhenLocationIsDisabled {
    // setup and test swizzle
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnNO)];
    STAssertEquals(NO, [CLLocationManager locationServicesEnabled], @"CLLocationManager should return NO");
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    testLocationManager_.locationManager = mockLocationManager;
    // Mock objects that receive messages that are not stubbed or expected will throw an exception
    STAssertThrows([mockLocationManager startUpdatingLocation], @"mockLocationManager should throw exception");
    STAssertNoThrow([testLocationManager_ startUpdatingLocation], @"Exception thown in testLocationManager, CLLocationManager object should not receive any messages");
    UALocationManagerStatus managerStatus = testLocationManager_.currentStatus;
    STAssertEquals(UALocationManagerNotEnabled, managerStatus, @"testLocationManager status is not set properly");
    
}

- (void)testStartUpdatingLocationWhenLocationIsEnabledAndNotAuthorized {
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusDenied)];
    CLAuthorizationStatus status = kCLAuthorizationStatusDenied;
    STAssertEquals(kCLAuthorizationStatusDenied, status, @"CLLocationManger should return kCLAuthorizationStatusDenied (2) but returned %d", status);
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    testLocationManager_.locationManager = mockLocationManager;
    STAssertNoThrow([testLocationManager_ startUpdatingLocation], @"UALocationManager should not send a message to CLLocationManager instance, and no exception should be thown");
}

- (void)testStopUpdatingLocation {
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] stopUpdatingLocation];
    testLocationManager_.locationManager = mockLocationManager;
    [testLocationManager_ stopUpdatingLocation];
    [mockLocationManager verify];
                              
}

- (void)testDidChangeAuthorizationStatusDelegateCallback {
    [testLocationManager_.locationManager sendChangeAuthorizationCallToDelegateWithAuthrization:kCLAuthorizationStatusDenied];
}

#pragma mark -
#pragma Support Methods

- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector {
    NSError *swizzleError = nil;
    [CLLocationManager jr_swizzleClassMethod:oneSelector withClassMethod:anotherSelector error:&swizzleError];
    STAssertNil(swizzleError, @"Method swizzling for CLLocationManager failed with error %@", swizzleError.description);
}



@end
