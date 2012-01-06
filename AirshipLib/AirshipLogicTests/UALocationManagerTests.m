//
//  UALocationManagerTests.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/6/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "UALocationManager.h"

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
- (void) testGetSetMethods {
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


@end
