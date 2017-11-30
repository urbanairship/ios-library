/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessage+Internal.h"

@interface UAInAppMessageTest : UABaseTest
@property(nonatomic, strong) NSDictionary *json;
@end

@implementation UAInAppMessageTest

- (void)setUp {
    [super setUp];

    self.json = @{
                     @"message_id": @"",
                     @"display": @"something",
                     @"display_type": @{@"something":@"good"},
                     @"extras": @{@"foo":@"baz", @"baz":@"foo"}
                 };
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Helper method for verifying json/model equivalence
 */
- (void)verifyConsistency:(UAInAppMessage *)message {
    XCTAssertEqualObjects(message.identifier, self.json[UAInAppMessageIDKey]);

    XCTAssertEqualObjects(message.extras[@"foo"], self.json[UAInAppMessageExtrasKey][@"foo"]);
    XCTAssertEqualObjects(message.extras[@"baz"], self.json[UAInAppMessageExtrasKey][@"baz"]);

    XCTAssertEqualObjects(message.displayContent, self.json[UAInAppMessageDisplayContentKey]);
    XCTAssertEqual(message.displayType, @"banner");

    XCTAssertEqualObjects(message.json, self.json);
}

/**
 * Test that payloads get turned into model objects properly
 */
- (void)testMessageWithPayload {
    UAInAppMessage *iam = [UAInAppMessage messageWithJSON:self.json error:nil];
    [self verifyConsistency:iam];
}

@end
