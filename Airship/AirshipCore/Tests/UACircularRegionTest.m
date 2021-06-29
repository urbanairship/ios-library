/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UACircularRegionTest : UABaseTest

@end

@implementation UACircularRegionTest

- (void)setUp {
    [super setUp];
}

/**
 * Test creating a circular region with a valid radius
 */
- (void)testSetValidRadius {
    double radius = 10;
    double latitude = 45.5200;
    double longitude = 122.6819;

    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNotNil(circularRegion);
}

/**
 * Test creating a circular region and adding an invalid radius
 */
- (void)testSetInvalidRadius {
    double radius = 100001;
    double latitude = 45.5200;
    double longitude = 122.6819;

    // test radius greater than max
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if radius fails to set.");

    // test radius less than min
    radius = 0;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if radius fails to set.");
}

/**
 * Test creating a circular region and adding a valid latitude
 */
- (void)testSetValidLatitude {
    double radius = 10;
    double latitude = 45.5200;
    double longitude = 122.6819;

    // test Portland's latitude
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNotNil(circularRegion);

    // test latitude of 0 degrees
    latitude = 0;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNotNil(circularRegion);
}

/**
 * Test creating a circular region and adding invalid latitudes
 */
- (void)testSetInvalidLatitude {
    double radius = 10;
    double latitude = 91;
    double longitude = 122.6819;

    // test latitude greater than max
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if latitude fails to set.");

    // test latitude less than min
    latitude = -91;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion, @"Circular region should be nil if latitude fails to set.");
}

/**
 * Test creating a circular region and adding a valid longitude
 */
- (void)testSetValidLongitude {
    double radius = 10;
    double latitude = 45.5200;
    double longitude = 122.6819;

    // test Portland's longitude
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNotNil(circularRegion);

    // test longitude of 0 degrees
    longitude = 0;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNotNil(circularRegion);
}

/**
 * Test creating a circular region and adding invalid longitudes
 */
- (void)testSetInvalidLongitude {
    double radius = 10;
    double latitude = 45.5200;
    double longitude= 181;

    // test longitude greater than max
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion);

    // test longitude less than min
    longitude = -181;
    circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];
    XCTAssertNil(circularRegion);
}

@end
