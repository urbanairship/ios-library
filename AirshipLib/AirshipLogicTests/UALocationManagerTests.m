//
//  UALocationManagerTests.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/6/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import "UALocationManager.h"
#import "JRSwizzle.h"

@interface CLLocationManager (Test)
+ (BOOL)returnYES;
+ (BOOL)returnNO;
+ (CLAuthorizationStatus)returnCLLocationStatusAuthorized;
+ (CLAuthorizationStatus)returnCLLocationStatusDenied;
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
@end


@interface UALocationManagerTests : SenTestCase {
    UALocationManager *testLocationManager_;
}
@end

@implementation UALocationManagerTests

- (void)setUp {
    testLocationManager_ = [[UALocationManager alloc] init];
    STAssertNotNil(testLocationManager_, @"location manager is nil!");
}

- (void)tearDown {
    [testLocationManager_ release];
    testLocationManager_ = nil;
}

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
    NSError* locationServiceSwizzleError = nil;
    [CLLocationManager jr_swizzleClassMethod:@selector(locationServicesEnabled) withClassMethod:@selector(returnYES) error:&locationServiceSwizzleError];
    STAssertNil(locationServiceSwizzleError, @"LocationServicesSwizzle fail");
    NSError* authoriztionSwizzleError = nil;
    [CLLocationManager jr_swizzleClassMethod:@selector(authorizationStatus) withClassMethod:@selector(returnCLLocationStatusAuthorized) error:&authoriztionSwizzleError];
    STAssertNil(authoriztionSwizzleError, @"AuthorizationSwizzle fail");
    // Setup mock object and message expectations
    STAssertEquals(kCLAuthorizationStatusAuthorized, [CLLocationManager authorizationStatus], @"authoriztionStatus swizzling failed");
    STAssertEquals(YES, [CLLocationManager locationServicesEnabled], @"locationServices not enabled");
    //Setup the mock object and expected messages
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] startUpdatingLocation];
    testLocationManager_.locationManager = mockLocationManager;
    [testLocationManager_ startUpdatingLocation];
    [mockLocationManager verify];
}
@end
