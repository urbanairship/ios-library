/* Copyright Airship and Contributors */

#import "UABaseTest.h"
@import AirshipCore;

@interface UAProximityRegionTest : UABaseTest

@end

@implementation UAProximityRegionTest

- (void)setUp {
    [super setUp];
}

/**
 * Test creating a proximity region with a valid proximity ID major and minor
 */
- (void)testCreateValidProximityRegion {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    double major = 1;
    double minor = 2;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    XCTAssertNotNil(proximityRegion);
}

/**
 * Test creating a proximity region with invalid proximity IDs
 */
- (void)testSetInvalidProximityID{
    NSString *proximityID = [@"" stringByPaddingToLength:256 withString:@"PROXIMITY_ID" startingAtIndex:0];
    double major = 1;
    double minor = 2;

    // test proximity ID greater than max
    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if proximity ID fails to set.");

    // test proximity ID less than min
    proximityID =  @"";
    proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if proximity ID fails to set.");
}

/**
 * Test creating a proximity region with invalid major and minor
 */
- (void)testSetInvalidMajorMinor{
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    double major = -1;
    double minor = -2;

    // test major and minor less than min
    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if major or minor fails to set.");


    // test major and minor greater than max
    major = UINT16_MAX+1;
    minor = UINT16_MAX+1;
    proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if major or minor fails to set.");
}

/**
 * Test creating a proximity region with a valid RSSI
 */
- (void)testSetValidRSSI {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    double major = 1;
    double minor = 2;
    double RSSI = -59;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID
                                                                            major:major
                                                                            minor:minor
                                                                             rssi:RSSI];

    // test an RSSI of -59 dBm
    XCTAssertNotNil(proximityRegion);

    // test RSSI of 0 dBm
    RSSI = 0;
    proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID
                                                                            major:major
                                                                            minor:minor
                                                                             rssi:RSSI];

    XCTAssertNotNil(proximityRegion);
}

/**
 * Test creating a proximity region and setting a invalid RSSIs
 */
- (void)testSetInvalidRSSI {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    double major = 1;
    double minor = 2;
    double RSSI = 101;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID
                                                                            major:major
                                                                            minor:minor
                                                                             rssi:RSSI];
    XCTAssertNil(proximityRegion, @"RSSIs over 100 or under -100 dBm should be ignored.");

    // test RSSI less than min
    RSSI = -101;
    proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID
                                                                            major:major
                                                                            minor:minor
                                                                             rssi:RSSI];

    XCTAssertNil(proximityRegion, @"RSSIs over 100 or under -100 dBm should be ignored.");
}
@end
