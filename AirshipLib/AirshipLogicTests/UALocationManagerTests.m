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


@interface UALocationManagerTests : SenTestCase {
    UALocationManager *testLocationManager_;
}

+ (BOOL)returnYES;
+ (BOOL)returnNO;
@end

@implementation UALocationManagerTests

+ (BOOL)returnNO {
    return NO;
}

+ (BOOL)returnYES {
    return YES;
}

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

- (void)testStartUpdatingLocation {
    id mockLocationManager = [OCMockObject mockForClass:[CLLocationManager class]];
    [[mockLocationManager expect] startUpdatingLocation];
    testLocationManager_.locationManager = mockLocationManager;
    NSError* swizzleError = nil;
    // + (BOOL)jr_swizzleClassMethod:(SEL)origSel_ withClassMethod:(SEL)altSel_ error:(NSError**)error_;
    [CLLocationManager jr_swizzleClassMethod:@selector(locationServicesEnabled) withClassMethod:@selector(returnNO) error:&swizzleError];
    NSLog(@"Error %@", swizzleError.description);
//    [testLocationManager_ startUpdatingLocation];
//    [mockLocationManager verify];

}
@end
