/* Copyright Airship and Contributors */

#import "UABaseTest.h"


@import AirshipCore;

@interface UAAssociateIdentifiersEventTest : UABaseTest

@end

@implementation UAAssociateIdentifiersEventTest

/**
 * Test the event's type.
 */
- (void)testType {
    UAAssociatedIdentifiers *identifiers = [UAAssociatedIdentifiers identifiers];
    UAAssociateIdentifiersEvent *event = [[UAAssociateIdentifiersEvent alloc] initWithIdentifiers:identifiers];
    XCTAssertEqualObjects(@"associate_identifiers", event.eventType);
}

/**
 * Test the event's data
 */
- (void)testData {
    UAAssociatedIdentifiers *identifiers = [UAAssociatedIdentifiers identifiers];
    identifiers.vendorID = @"vendor ID";
    identifiers.advertisingID = @"ad ID";
    identifiers.advertisingTrackingEnabled = YES;

    UAAssociateIdentifiersEvent *event = [[UAAssociateIdentifiersEvent alloc] initWithIdentifiers:identifiers];

    XCTAssertEqualObjects(identifiers.allIDs, event.data);
}

@end
