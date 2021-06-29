/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

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

@end
