/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#import <XCTest/XCTest.h>
#import "UACircularRegion+Internal.h"

@interface UACircularRegionTest : XCTestCase

@end

@implementation UACircularRegionTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test creating a circular region with a valid radius
 */
- (void)testSetValidRadius {
    NSNumber *radius = @10;
    NSNumber *latitude = @45.5200;
    NSNumber *longitude = @122.6819;

    // test radius of 10 meters
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertEqualObjects(radius, circularRegion.radius, @"Unexpected radius.");
}

/**
 * Test creating a circular region and adding an invalid radius
 */
- (void)testSetInvalidRadius {
    NSNumber *radius = @(100001);
    NSNumber *latitude = @45.5200;
    NSNumber *longitude = @122.6819;

    // test radius greater than max
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if radius fails to set.");

    // test radius less than min
    radius = @0;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if radius fails to set.");

    // test nil radius
    radius = nil;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if radius fails to set.");
}

/**
 * Test creating a circular region and adding a valid latitude
 */
- (void)testSetValidLatitude {
    NSNumber *radius = @10;
    NSNumber *latitude = @45.5200;
    NSNumber *longitude = @122.6819;

    // test Portland's latitude
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertEqualObjects(latitude, circularRegion.latitude, @"Unexpected latitude.");

    // test latitude of 0 degrees
    latitude = @0;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertEqualObjects(@0, circularRegion.latitude, @"Unexpected latitude.");
}

/**
 * Test creating a circular region and adding invalid latitudes
 */
- (void)testSetInvalidLatitude {
 NSNumber *radius = @10;
    NSNumber *latitude = @(91);
    NSNumber *longitude = @122.6819;

    // test latitude greater than max
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if latitude fails to set.");

    // test latitude less than min
    latitude = @(-91);
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if latitude fails to set.");
}

/**
 * Test creating a circular region and adding a valid longitude
 */
- (void)testSetValidLongitude {
    NSNumber *radius = @10;
    NSNumber *latitude = @45.5200;
    NSNumber *longitude = @122.6819;

    // test Portland's longitude
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertEqualObjects(circularRegion.longitude, circularRegion.longitude, @"Unexpected longitude.");

    // test longitude of 0 degrees
    longitude = @0;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertEqualObjects(@0, circularRegion.longitude, @"Unexpected longitude.");
}

/**
 * Test creating a circular region and adding invalid longitudes
 */
- (void)testSetInvalidLongitude {
    NSNumber *radius = @10;
    NSNumber *latitude = @45.5200;
    NSNumber *longitude= @(181);

    // test longitude greater than max
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if longitude fails to set.");

    // test longitude less than min
    longitude = @(-181);
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if longitude fails to set.");

    // test nil longitude
    longitude = nil;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Nil longitudes should fail validation.");
}

@end
