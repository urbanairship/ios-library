/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UACircularRegion+Internal.h"

@interface UACircularRegionTest : UABaseTest

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
