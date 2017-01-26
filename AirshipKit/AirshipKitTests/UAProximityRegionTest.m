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
#import "UAProximityRegion+Internal.h"

@interface UAProximityRegionTest : XCTestCase

@end

@implementation UAProximityRegionTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test creating a proximity region with a valid proximity ID major and minor
 */
- (void)testCreateValidProximityRegion {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    XCTAssertEqualObjects(proximityID, proximityRegion.proximityID, @"Unexpected proximity ID.");
    XCTAssertEqualObjects(major, proximityRegion.major, @"Unexpected major.");
    XCTAssertEqualObjects(minor, proximityRegion.minor, @"Unexpected minor.");
}

/**
 * Test creating a proximity region with invalid proximity IDs
 */
- (void)testSetInvalidProximityID{
    NSString *proximityID = [@"" stringByPaddingToLength:256 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    // test proximity ID greater than max
    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if proximity ID fails to set.");

    // test proximity ID less than min
    proximityID =  @"";
    proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if proximity ID fails to set.");

    // test nil proximity ID
    proximityID =  nil;
    proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if proximity ID fails to set.");
}

/**
 * Test creating a proximity region with invalid major and minor
 */
- (void)testSetInvalidMajorMinor{
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @-1;
    NSNumber *minor = @-2;

    // test major and minor less than min
    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if major or minor fails to set.");


    // test major and minor greater than max
    major = @(UINT16_MAX+1);
    minor = @(UINT16_MAX+1);
    proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];
    XCTAssertNil(proximityRegion, @"Proximity region should be nil if major or minor fails to set.");
}

/**
 * Test creating a proximity region with a valid RSSI
 */
- (void)testSetValidRSSI {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    // test an RSSI of -59 dBm
    proximityRegion.RSSI = @-59;
    XCTAssertEqualObjects(@-59, proximityRegion.RSSI, @"Unexpected RSSI.");

    // test RSSI of 0 dBm
    proximityRegion.RSSI = @0;
    XCTAssertEqualObjects(@0, proximityRegion.RSSI, @"Unexpected RSSI.");

    // test nil RSSI
    proximityRegion.RSSI = nil;
    XCTAssertNil(proximityRegion.RSSI, @"Unexpected RSSI.");
}

/**
 * Test creating a proximity region and setting a invalid RSSIs
 */
- (void)testSetInvalidRSSI {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    // test RSSI greater than max
    proximityRegion.RSSI =  @(101);
    XCTAssertNil(proximityRegion.RSSI, @"RSSIs over 100 or under -100 dBm should be ignored.");

    // test RSSI less than min
    proximityRegion.RSSI = @(-101);
    XCTAssertNil(proximityRegion.RSSI, @"RSSIs over 100 or under -100 dBm should be ignored.");
}

/**
 * Test creating a proximity region and adding a valid latitude
 */
- (void)testSetValidLatitude {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    // test Portland's latitude
    NSNumber *latitude = @45.5200;
    proximityRegion.latitude = latitude;
    XCTAssertEqualObjects(latitude, proximityRegion.latitude, @"Unexpected latitude.");

    // test latitude of 0 degrees
    proximityRegion.latitude = @0;
    XCTAssertEqualObjects(@0, proximityRegion.latitude, @"Unexpected latitude.");

    // test nil latitude
    proximityRegion.latitude = nil;
    XCTAssertNil(proximityRegion.latitude, @"Unexpected latitude.");

}

/**
 * Test creating a proximity region and setting invalid latitudes
 */
- (void)testSetInvalidLatitude {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    // test latitude greater than max
    NSNumber *latitude = @(91);
    proximityRegion.latitude = latitude;
    XCTAssertNil(proximityRegion.latitude, @"Latitudes over 90 degrees or under -90 degrees should be ignored.");

    // test latitude less than min
    latitude = @(-91);
    proximityRegion.latitude = latitude;
    XCTAssertNil(proximityRegion.latitude, @"Latitudes over 90 degrees or under -90 degrees should be ignored.");
}

/**
 * Test creating a proximity region and adding a valid longitude
 */
- (void)testSetValidLongitude {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    NSNumber *longitude = @122.6819;

    // test Portland's longitude
    proximityRegion.longitude = longitude;
    XCTAssertEqualObjects(longitude, proximityRegion.longitude, @"Unexpected longitude.");

    // test longitude of 0 degrees
    proximityRegion.longitude = @0;
    XCTAssertEqualObjects(@0, proximityRegion.longitude, @"Unexpected longitude.");

    // test nil longitude
    proximityRegion.longitude = nil;
    XCTAssertNil(proximityRegion.longitude, @"Unexpected longitude");
}

/**
 * Test creating a proximity region and setting invalid longitudes
 */
- (void)testSetInvalidLongitude {
    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    // test longitude greater than max
    NSNumber *longitude=  @(181);
    proximityRegion.longitude = longitude;
    XCTAssertNil(proximityRegion.longitude, @"Longitudes over 180 degrees or under -180 degrees should be ignored.");

    // test longitude less than min
    longitude = @(-181);
    proximityRegion.longitude = longitude;
    XCTAssertNil(proximityRegion.longitude, @"Longitudes over 180 degrees or under -180 degrees should be ignored.");
}

@end
