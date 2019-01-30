/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAAssociatedIdentifiers.h"

@interface UAAssociatedIdentifiersTest : UABaseTest
@end

@implementation UAAssociatedIdentifiersTest

/**
 * Test identifier ID mapping
 */
- (void)testIDs {
    UAAssociatedIdentifiers *identifiers = [UAAssociatedIdentifiers identifiersWithDictionary:@{@"custom key": @"custom value"}];
    identifiers.vendorID = @"vendor ID";
    identifiers.advertisingID = @"advertising ID";
    identifiers.advertisingTrackingEnabled = NO;
    [identifiers setIdentifier:@"another custom value" forKey:@"another custom key"];

    XCTAssertEqualObjects(@"vendor ID", identifiers.allIDs[@"com.urbanairship.vendor"]);
    XCTAssertEqualObjects(@"advertising ID", identifiers.allIDs[@"com.urbanairship.idfa"]);
    XCTAssertFalse(identifiers.advertisingTrackingEnabled);
    XCTAssertEqualObjects(@"true", identifiers.allIDs[@"com.urbanairship.limited_ad_tracking_enabled"]);
    XCTAssertEqualObjects(@"another custom value", identifiers.allIDs[@"another custom key"]);

    identifiers.advertisingTrackingEnabled = YES;
    XCTAssertTrue(identifiers.advertisingTrackingEnabled);
    XCTAssertEqualObjects(@"false", identifiers.allIDs[@"com.urbanairship.limited_ad_tracking_enabled"]);
}

/**
 * Test creating associated identifiers with invalid dictionary
 */
- (void)testAssociateDeviceIdentifiersInvalidDictionary {

    NSDictionary *invalidDictionary = @{@"some identifier": @2};
    UAAssociatedIdentifiers *identifiers = [UAAssociatedIdentifiers identifiersWithDictionary:invalidDictionary];
    XCTAssertEqual(identifiers.allIDs.count, 0, @"Should be empty associated identifiers instance.");

    NSDictionary *anotherInvalidDictionary = @{@2: @"identifier"};
    UAAssociatedIdentifiers *someIdentifiers = [UAAssociatedIdentifiers identifiersWithDictionary:anotherInvalidDictionary];
    XCTAssertEqual(someIdentifiers.allIDs.count, 0, @"Should be empty associated identifiers instance.");
}

@end
