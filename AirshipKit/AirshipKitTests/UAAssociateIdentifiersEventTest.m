/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAAssociateIdentifiersEvent+Internal.h"

@interface UAAssociateIdentifiersEventTest : UABaseTest

@end

@implementation UAAssociateIdentifiersEventTest

/**
 * Test the event's type.
 */
- (void)testType {
    XCTAssertEqualObjects(@"associate_identifiers", [[UAAssociateIdentifiersEvent alloc] init].eventType);
}

/**
 * Test the event's data
 */
- (void)testData {
    UAAssociatedIdentifiers *identifiers = [UAAssociatedIdentifiers identifiers];
    identifiers.vendorID = @"vendor ID";
    identifiers.advertisingID = @"ad ID";
    identifiers.advertisingTrackingEnabled = YES;

    UAAssociateIdentifiersEvent *event = [UAAssociateIdentifiersEvent eventWithIDs:identifiers];

    XCTAssertEqualObjects(identifiers.allIDs, event.data);
}

@end
